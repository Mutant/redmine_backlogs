require 'set'

# This subclass of Workflow represents workflows for
# RbSprintTaskTracker.
#
# It's RbTaskWorkflow's job to ensure we have the right number of
# workflows to support 1) the default task statuses and 2) per-project
# task statuses that override the defaults in 1). See
# RbProjectTaskStatus model.

class RbTaskWorkflow < Workflow

  # Generate a uniquely characterising id for a workflow.

  def self.wid tracker_id,role_id,old_id,new_id
    "%s-%s-%s-%s" % [tracker_id,role_id,old_id,new_id]
  end

  # Unpack a wid into a hash that could be used with 'find'.
  #
  # See self.wid.

  def self.wid_unpack wid
    arr = wid.split('-')
    {
      :tracker_id => arr[0].to_i,
      :role_id => arr[1].to_i,
      :old_status_id => arr[2].to_i,
      :new_status_id => arr[3].to_i
    }
  end

  # Fetch all existing workflows for RbSprintTaskTracker.

  def self.all
    self.find(:all,
              :conditions => {
                :tracker_id => RbSprintTaskTracker.id})
  end

  # Return wid for this workflow.
  #
  # See self.wid.

  def wid
    self.class.wid(
      self.tracker_id,
      self.role_id,
      self.old_status_id,
      self.new_status_id
    )
  end

  # Insert missing workflows, remove unused for RbSprintTaskTracker.
  #
  # Returns array of saved Workflow objects.
  #
  # See missing_workflows for what determines a missing workflow.
  # Unused workflows are also destroyed.

  def self.synchronize!
    self.unused_workflows.each{|w|
      w = Workflow.find(:first,:conditions => w)
      w.destroy if w
    }
    self.missing_workflows.map{|w|
      w = Workflow.new(w)
      w.save!
      w
    }
  end

  # Find workflows that exist but which are no longer used.
  #
  # Returns in the same format as workflows_for.

  def self.unused_workflows
    all = self.all.map{|w|w.wid}
    required = self.required_workflows.map{|w|w[:wid]}
    sall = Set.new(all)
    sreq = Set.new(required)
    sdelete = sall-sreq
    sdelete.map {|wid|
      self.wid_unpack(wid)
    }.compact
    
  end

  # Return array of any workflows that should be added to the tracker.
  #
  # Returns in the same format as workflows_for.

  def self.missing_workflows
    all = self.all.map{|w|w.wid}
    required = self.required_workflows.map{|w|w[:wid]}
    sall = Set.new(all)
    sreq = Set.new(required)
    smissing = sreq-sall
    smissing.map {|wid|
      RbTaskWorkflow.wid_unpack(wid)
    }.compact

  end

  # Returns all the workflows we *should* have for
  # RbSprintTaskTracker.
  #
  # Returns in the same format as workflows_for.
  #
  # We require workflows for:
  # - The default tracker statuses (which get altered
  #   on the main backlogs settings page).
  #   See Backlogs.setting[:default_task_statuses].
  # - A project has overridden the defaults and has
  #   specified its own issue statuses.
  # This is done for all roles at the moment.

  def self.required_workflows
    result = []
    ids = RbProjectTaskStatus.all_issue_status_ids.keys
    roles = RbSprintTaskTracker.roles
    role_ids = roles.map{|r|r.id}
    tracker_id = RbSprintTaskTracker.id
    ids.combination(2).each{|comb2|
      result.concat(self.workflows_for(tracker_id,role_ids,comb2[0],comb2[1]))
    }
    result
  end

  # Determine all possible workflows for 2 issue statuses for all
  # roles for a given tracker_id.
  # 
  # Returns:
  #   [wflow1,wflow2,...]
  # where
  #   wflowN is {:tracker_id => ...,...}
  # which is the same format as self.wid_unpack .

  def self.workflows_for tracker_id,role_ids,status_id1,status_id2
    workflows = []
    add = proc{|status_id1,status_id2|
      role_ids.map {|role_id|
        attr = {
          :tracker_id => tracker_id,
          :old_status_id => status_id1,
          :new_status_id => status_id2,
          :role_id => role_id,
          :wid => self.wid(tracker_id,role_id,status_id1,status_id2)
        }
      }
    }
    workflows.concat(add.call(status_id1,status_id2))
    workflows.concat(add.call(status_id2,status_id1))
    workflows
  end

end
