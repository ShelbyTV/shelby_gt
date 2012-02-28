# Rake has no way built in to override tasks already defined, this provides that via override_task
#
# To override, just define a rake tasks via override_task (as opposed to task)
#
# To invoke the original task add ":original" to its name
#   Rake::Task["db:test:prepare:original"].execute
#
# WHY? 
# Created because MongoMapper defines db:test:prepare which assume defualt MM connection, which we don't have.
# Althought MM checks if db:test:prepare is alredy defined, and then doesn't define itself, I don't want to rely on that
# since it could change at any moment.

Rake::TaskManager.class_eval do
  def alias_task(fq_name)
    new_name = "#{fq_name}:original"
    @tasks[new_name] = @tasks.delete(fq_name)
  end
end

def alias_task(fq_name)
  Rake.application.alias_task(fq_name)
end

def override_task(*args, &block)
  name, params, deps = Rake.application.resolve_args(args.dup)
  fq_name = Rake.application.instance_variable_get(:@scope).dup.push(name).join(':')
  alias_task(fq_name)
  Rake::Task.define_task(*args, &block)
end