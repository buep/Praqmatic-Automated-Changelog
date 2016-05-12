# encoding: utf-8
require 'yaml'
require_relative "./task.rb"
require_relative "./gitvcs"
require_relative "./mercurialvcs"

module Core extend self

  def settings
    @@settings
  end

  def settings=(val)
    @@settings = val
  end

  #Reads the command line options. And based on this it will return the 
  #path of the settings file to use.
  def read_settings_file(input)
    settings_file = File.join(Dir.pwd, 'default_settings.yml')
    unless input['--settings'].nil?
      settings_file = input['--settings']
    end
    File.read(settings_file)
  end

  #Creates the final settings based on additonal command line arguments
  #Parameters
  # cmdline       - The command line arguments parsed by docopt. Essentially a ruby hash
  # configuration - The contents of the settings file
  #Exceptions
  # All exections are throw as is. Handled in pac.rb.
  def generate_settings(cmdline, configuration)
    loaded = YAML::load(configuration)

    if loaded[:properties].nil?
      loaded[:properties] = {}
    end

    unless cmdline['--pattern'].nil? 
      loaded[:vcs][:release_regex] = input['--pattern']
    end

    unless cmdline['--properties'].nil? 
      json_value = JSON.parse(cmdline['--properties'])
      loaded[:properties] = loaded[:properties].merge(json_value)
    end
    loaded    
  end
  
  #Requires a configuration section for the task system to be applied
  def apply_task_system(task_system, tasks)
    puts "[PAC] Applying task system #{task_system[:name]}"
    if task_system[:name] == 'trac'      
      Task::TracTaskSystem.new(task_system).apply(tasks)
    end
    if task_system[:name] == 'jira'
      Task::JiraTaskSystem.new(task_system).apply(tasks)
    end   
  end
  
  def vcs
    if @@settings[:vcs][:type] == 'git'
      Vcs::GitVcs.new(settings[:vcs])
    elsif @@settings[:vcs][:type] == 'hg'
      Vcs::MercurialVcs.new(@@settings[:vcs])
    else
      raise ArgumentError, 'The configuration settings does not include any supported (d)vcs'
    end
  end
  
  def to_time(datestring)
    DateTime.strptime(datestring, @@settings[:general]['date_template']).to_time    
  end

  #This is now core functionality. The task of generating a collection of tasks based on the commits found
  #This takes in a PACCommitCollection and returns a PACTaskCollection 
  def task_id_list(commits)
    regex_arr = []

    tasks = Model::PACTaskCollection.new

    commits.each do |c_pac|

      referenced = false
      #Regex ~ Eacb regex in the task system
      settings[:task_systems].each do |ts|
        #Loop over each task system. Parse commits for matches
        if ts.has_key? :delimiter 
          split_pattern = eval(ts[:delimiter]) 
        end

        if ts.has_key? :regex 
          tasks_for_commit = c_pac.matchtask(ts[:regex], split_pattern)
          tasks_for_commit.each do |t|    
            t.applies_to = ts[:name]
          end            
          #If a task was found
          unless tasks_for_commit.empty?
            referenced = true          
            tasks.add(tasks_for_commit)                
          end          
        end
      end

      if !referenced
        task = Model::PACTask.new
        task.add_commit(c_pac)
        tasks.add(task)
      end      

    end

    tasks      
  end

end
