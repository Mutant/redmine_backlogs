# Base class of all controllers in Redmine Backlogs
class RbApplicationController < ApplicationController
  unloadable

  before_filter :load_project, :authorize, :check_if_plugin_is_configured, :synchronize_task_workflows

  private

  # Loads the project to be used by the authorize filter to
  # determine if User.current has permission to invoke the method in question.
  def load_project
    @project = if params[:sprint_id]
                 load_sprint
                 @sprint.project
               elsif params[:release_id]
                 load_release
                 @release.project
               elsif params[:project_id]
                 Project.find(params[:project_id])
               else
                 raise "Cannot determine project (#{params.inspect})"
               end
  end

  def check_if_plugin_is_configured
    @settings = Backlogs.settings
    if @settings[:story_trackers].blank? || @settings[:task_tracker].blank?
      respond_to do |format|
        format.html { render :file => "shared/not_configured" }
      end
    end
  end

  def load_sprint
    @sprint = RbSprint.find(params[:sprint_id])
  end

  def load_release
    @release = RbRelease.find(params[:release_id])
  end

  # Synchronize workflows when default task statuses change.
  #
  # We already synchronize! in RbProjectTaskStatus#after_save for
  # per-project task statuses. Here we look for a flag set in
  # app/views/backlogs/_settings.html.erb which tells us if a user
  # has changed the default task statuses.

  def synchronize_task_workflows
    key = 'default_task_statuses_changed'
    if Backlogs.setting[key]=='true' then
      Rails.logger.info("[synchronize_task_workflows] defaults have changed, synchronizing!")
      RbTaskWorkflow.synchronize!
      Backlogs.setting[key]=false
    end
  end

end
