class ImpasseExecStepHistsController < ApplicationController
  unloadable

  menu_item :impasse
  before_filter :find_project_by_project_id, :only => [:new, :create,:execution_step,:create_step_bug]
  before_filter :check_for_default_issue_status, :only => [:new, :create, :create_step_bug]
  before_filter :build_new_issue_from_params, :only => [:new, :create, :create_step_bug]

  helper :journals
  helper :projects
  include ProjectsHelper
  helper :custom_fields
  include CustomFieldsHelper
  helper :issue_relations
  include IssueRelationsHelper
  helper :watchers
  include WatchersHelper
  helper :attachments
  include AttachmentsHelper
  helper :queries
  include QueriesHelper
  helper :repositories
  include RepositoriesHelper
  helper :sort
  include SortHelper
  include IssuesHelper
  
  
  include ActionView::Helpers::AssetTagHelper
  
  def new
    setting = Impasse::Setting.find_or_create_by_project_id(@project)
    unless setting.bug_tracker_id.nil?
      unless @project.trackers.find_by_id(setting.bug_tracker_id).nil?
      @issue.tracker_id = setting.bug_tracker_id
      end
    end

    respond_to do |format|
      format.html { render :partial => 'new' }
      format.js   { render :partial => 'issues/attributes' }
    end
  end

  def put
    begin

      paramsExecStepHists = {test_steps_id: null, 
                             test_plan_case_id: null,
                             issue_id: null,
                             author_id: null,
                             project_id: null,
                             tester_id: null,
                             build_id: null,
                             expected_date: null,
                             status: null,
                             executions_ts: null,
                             executor_id: null,
                             created_at: null,
                             updated_at: null}

      ActiveRecord::Base.transaction do
        @execution_history_step = Impasse::ExecStepHists.new(params[:execution])
        @execution_history_step.save!
        render :json => { :status => 'success', :message => l(:notice_successful_update) }
      end
    rescue
      render :json => { :status => 'error', :message => l(:error_failed_to_update), :errors => @execution_history_step }
    end
  end
  
   def put_step
    begin
      ActiveRecord::Base.transaction do
        @execution_history_step = Impasse::ExecStepHists.new(params[:execution])
        @execution_history_step.save!
        render :json => { :status => 'success', :message => l(:notice_successful_update) }
      end
    rescue
      render :json => { :status => 'error', :message => l(:error_failed_to_update), :errors => @execution_history_step }
    end
  end
    
   def execution_step
      @execution_bug_step = Impasse::ExecStepHist.new   
      @execution_bug_step.project = @project
      @execution_bug_step.author = User.current
      @execution_bug_step.execution_ts = Time.now.to_datetime
      @execution_bug_step.executor_id = User.current.id
      @execution_bug_step.test_steps_id = params[:test_step_id]  
      @execution_bug_step.test_plan_case_id = params[:test_plan_case_id]
      @execution_bug_step.test_plan_case_id = params[:test_case_id]
      @execution_bug_step.status = params[:test_step_status]
    
    if  @execution_bug_step.save  
      flash[:notice] = l(:notice_successful_create)
      respond_to do |format|
        format.json  { render :json => { :status => 'success'} }
      end
    else
        respond_to do |format|
        format.json { render :json => { :status => 'error', :errors => @execution_bug_step.errors.full_messages } }
      end
    end
  end

  def create_step_bug
    call_hook(:controller_issues_new_before_save, { :params => params, :issue => @issue })
        
     if @issue.save
      @execution_bug_step = Impasse::ExecStepHist.new    
      @execution_bug_step.project = @project
      @execution_bug_step.author = User.current
      @execution_bug_step.execution_ts = Time.now.to_datetime
      @execution_bug_step.executor_id = User.current.id
      @execution_bug_step.test_steps_id = params[:issue][:test_steps_id]  
      @execution_bug_step.test_plan_case_id = params[:issue][:test_plan_case_id]
      @execution_bug_step.test_plan_case_id = params[:issue][:test_case_id]
      @execution_bug_step.status = params[:issue][:test_step_status]
      @execution_bug_step.issue_id = @issue.id
        
     @execution_bug_step.save!
         
     flash[:notice] = l(:notice_successful_create)
      respond_to do |format|
        format.json  { render :json => { :status => 'success', :issue_id => @issue.id } }
      end
    else
      respond_to do |format|
        format.json { render :json => { :status => 'error', :errors => @issue.errors.full_messages } }
      end
    end
  end

  def upload_attachments
    issue = Issue.find(params[:issue_id])
    attachments = Attachment.attach_files(issue, params[:attachments])

    respond_to do |format|
      format.html { render :text => 'ok' }
    end
  end

  def build_new_issue_from_params
    if params[:id].blank?
      @issue = Issue.new
      if params[:copy_from]
        begin
          @copy_from = Issue.visible.find(params[:copy_from])
          @copy_attachments = params[:copy_attachments].present? || request.get?
          @copy_subtasks = params[:copy_subtasks].present? || request.get?
          @issue.copy_from(@copy_from, :attachments => @copy_attachments, :subtasks => @copy_subtasks)
        rescue ActiveRecord::RecordNotFound
          render_404
          return
        end
      end
      @issue.project = @project
    else
      @issue = @project.issues.visible.find(params[:id])
    end

    @issue.project = @project
    @issue.author ||= User.current
    # Tracker must be set before custom field values
    @issue.tracker ||= @project.trackers.find((params[:issue] && params[:issue][:tracker_id]) || params[:tracker_id] || :first)

    if @issue.tracker.nil?
      render_error l(:error_no_tracker_in_project)
      return false
    end
    @issue.start_date ||= Date.today if Setting.default_issue_start_date_to_creation_date?
    @issue.safe_attributes = params[:issue]

    setting = Impasse::Setting.find_or_create_by_project_id(@project)
    unless setting.bug_tracker_id.nil?
      unless @project.trackers.find_by_id(setting.bug_tracker_id).nil?
        @issue.tracker_id = setting.bug_tracker_id
      end
    end
    @priorities = IssuePriority.active
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current, true)
    @available_watchers = (@issue.project.users.sort + @issue.watcher_users).uniq
  end

  def check_for_default_issue_status
    if IssueStatus.default.nil?
      render_error l(:error_no_default_issue_status)
    return false
    end
  end
  
  def step_list
    
      sql = <<-END_OF_SQL
             SELECT tb1.*, issues.author_id as bug_author_id, 
              issues.subject as bug_subject, 
              issues.description as bug_description,
              issues.status_id, 
              issue_statuses.name as bug_status,
              users.firstname as executor_firstname
              FROM  (SELECT impasse_exec_step_hists.*
              FROM impasse_exec_step_hists 
              where test_steps_id=?) as tb1 
              left join issues on issues.id = tb1.issue_id
              left join issue_statuses on issues.status_id = issue_statuses.id
              left join users on users.id = tb1.executor_id
              order by tb1.execution_ts desc
              END_OF_SQL

    @executionsHist= Impasse::ExecStepHist.find_by_sql [sql,params[:test_step_id]]
    
        render :partial=>'list_edit'
  end
  
    def step_last
    
      sql = <<-END_OF_SQL
             SELECT impasse_exec_step_hists.*
              FROM impasse_exec_step_hists 
              where id = (SELECT max(id) 
                            FROM impasse_exec_step_hists 
                           WHERE test_steps_id=?
                           )
              END_OF_SQL

    @executionsHistStepLast = Impasse::ExecStepHist.find_by_sql [sql,params[:test_step_id]]
     
       respond_to do |format|
         @executionsHistStepLast.each do |executionsHistStepLast|
          format.json  { render :json => { :status => 'success', :status_step => executionsHistStepLast.status , :test_steps_id => executionsHistStepLast.test_steps_id, :test_plan_case_id => executionsHistStepLast.test_plan_case_id, :issue_id => executionsHistStepLast.issue_id, :project_id => executionsHistStepLast.project_id } }
          end
       end
  end
end