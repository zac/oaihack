#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'pathname'
require 'set'
require 'xcodeproj'

payload = JSON.parse(STDIN.read)
project_path = payload.fetch('project')
action = payload.fetch('action')
project = Xcodeproj::Project.open(project_path)
project_dir = Pathname.new(File.dirname(project_path))

module Helpers
  module_function

  def sorted_children?(group)
    names = group.children.map(&:display_name)
    names == names.sort_by { |n| n.downcase }
  end

  def sort_children!(group)
    group.children.sort_by! { |child| child.display_name.downcase }
  end

  def maybe_sort(group)
    sort_children!(group) if sorted_children?(group)
  end

  def resolve_targets(project, target_names, default_to_apps: true)
    if target_names && !target_names.empty?
      target_names.map { |name| project.targets.find { |t| t.name == name } }.compact
    elsif default_to_apps
      project.targets.select do |t|
        t.respond_to?(:product_type) && t.product_type == 'com.apple.product-type.application'
      end
    else
      project.targets
    end
  end

  def find_group(project, group_path)
    current = project.main_group
    group_path.split('/').each do |name|
      child = current.groups.find { |g| g.display_name == name }
      return nil unless child

      current = child
    end
    current
  end

  def ensure_group(project, group_path, project_dir)
    current = project.main_group
    group_path.split('/').each do |name|
      child = current.groups.find { |g| g.display_name == name }
      unless child
        parent_real = current.real_path || project_dir
        child_path = Pathname.new(parent_real).join(name)
        child = if child_path.directory?
                  current.new_group(name, name)
                else
                  current.new_group(name)
                end
      end
      current = child
    end
    current
  end

  def file_refs_for_path(project, file_path, project_dir)
    abs = Pathname.new(file_path)
    abs = project_dir.join(file_path) unless abs.absolute?
    abs = abs.cleanpath
    project.files.select do |ref|
      ref.respond_to?(:real_path) && ref.real_path && ref.real_path.cleanpath == abs
    end
  end

  def remove_file_from_targets(file_ref, targets)
    targets.each do |target|
      target.build_phases.each do |phase|
        next unless phase.respond_to?(:files)

        phase.files.dup.each do |build_file|
          if build_file.file_ref == file_ref
            phase.files.delete(build_file)
            build_file.remove_from_project
          end
        end
      end
    end
  end

  def requirement_hash(payload)
    if payload['version']
      { 'kind' => 'upToNextMajorVersion', 'minimumVersion' => payload['version'] }
    elsif payload['exact']
      { 'kind' => 'exactVersion', 'version' => payload['exact'] }
    elsif payload['branch']
      { 'kind' => 'branch', 'branch' => payload['branch'] }
    elsif payload['revision']
      { 'kind' => 'revision', 'revision' => payload['revision'] }
    else
      raise 'Package requirement missing (version/branch/revision/exact)'
    end
  end
end

case action
when 'add-files'
  group_path = payload.fetch('group')
  create_groups = payload.fetch('create_groups')
  files = payload.fetch('files')
  group = if create_groups
            Helpers.ensure_group(project, group_path, project_dir)
          else
            Helpers.find_group(project, group_path) || (raise "Group not found: #{group_path}")
          end

  targets = Helpers.resolve_targets(project, payload['targets'])

  files.each do |file_path|
    abs = Pathname.new(file_path)
    abs = project_dir.join(file_path) unless abs.absolute?
    abs = abs.cleanpath

    existing = group.files.find { |f| f.real_path && f.real_path.cleanpath == abs }
    file_ref = existing || group.new_file(abs.to_s)
    targets.each { |t| t.add_file_references([file_ref]) }
  end

  Helpers.maybe_sort(group)
  project.save
  puts "Added #{files.count} file(s) to #{group_path}."

when 'remove-files'
  files = payload.fetch('files')
  targets = Helpers.resolve_targets(project, payload['targets'], default_to_apps: false)

  files.each do |file_path|
    refs = Helpers.file_refs_for_path(project, file_path, project_dir)
    if refs.empty?
      warn "Warning: file not found in project: #{file_path}"
      next
    end
    refs.each do |ref|
      Helpers.remove_file_from_targets(ref, targets)
      ref.remove_from_project
    end
  end

  project.save
  puts "Removed #{files.count} file(s)."

when 'add-group'
  group_path = payload.fetch('group')
  group = Helpers.ensure_group(project, group_path, project_dir)
  Helpers.maybe_sort(group.parent) if group.respond_to?(:parent)
  project.save
  puts "Added group #{group_path}."

when 'remove-group'
  group_path = payload.fetch('group')
  recursive = payload['recursive']
  group = Helpers.find_group(project, group_path)
  raise "Group not found: #{group_path}" unless group

  raise "Group not empty; use --recursive to remove: #{group_path}" if !recursive && !group.children.empty?

  targets = Helpers.resolve_targets(project, payload['targets'], default_to_apps: false)

  if recursive
    group.children.each do |child|
      if child.is_a?(Xcodeproj::Project::Object::PBXFileReference)
        Helpers.remove_file_from_targets(child, targets)
        child.remove_from_project
      end
    end
  end

  group.remove_from_project
  project.save
  puts "Removed group #{group_path}."

when 'add-spm'
  url = payload.fetch('url')
  product = payload.fetch('product')
  requirement = Helpers.requirement_hash(payload)
  targets = Helpers.resolve_targets(project, payload['targets'])

  root = project.root_object
  root.package_references ||= []
  root.package_product_dependencies ||= []

  package_ref = root.package_references.find { |ref| ref.repositoryURL == url }
  unless package_ref
    package_ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
    package_ref.repositoryURL = url
    package_ref.requirement = requirement
    root.package_references << package_ref
  end

  product_dep = root.package_product_dependencies.find do |dep|
    dep.productName == product && dep.package == package_ref
  end

  unless product_dep
    product_dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
    product_dep.productName = product
    product_dep.package = package_ref
    root.package_product_dependencies << product_dep
  end

  targets.each do |target|
    target.package_product_dependencies ||= []
    target.package_product_dependencies << product_dep unless target.package_product_dependencies.include?(product_dep)
  end

  project.save
  puts "Added SPM package #{url} (#{product})."

when 'remove-spm'
  url = payload['url']
  product = payload.fetch('product')
  targets = Helpers.resolve_targets(project, payload['targets'], default_to_apps: false)
  root = project.root_object

  deps = root.package_product_dependencies || []
  deps_to_remove = deps.select { |dep| dep.productName == product }
  warn "Warning: product not found: #{product}" if deps_to_remove.empty?

  targets.each do |target|
    next unless target.respond_to?(:package_product_dependencies)

    deps_to_remove.each { |dep| target.package_product_dependencies.delete(dep) }
  end

  deps_to_remove.each do |dep|
    root.package_product_dependencies.delete(dep)
    dep.remove_from_project
  end

  if url
    package_ref = (root.package_references || []).find { |ref| ref.repositoryURL == url }
    if package_ref
      still_used = (root.package_product_dependencies || []).any? { |dep| dep.package == package_ref }
      unless still_used
        root.package_references.delete(package_ref)
        package_ref.remove_from_project
      end
    end
  end

  project.save
  puts "Removed SPM product #{product}."

when 'list-targets'
  targets = project.targets.map do |target|
    type = target.respond_to?(:product_type) ? target.product_type : 'unknown'
    type_short = case type
                 when 'com.apple.product-type.application' then 'app'
                 when 'com.apple.product-type.framework' then 'framework'
                 when 'com.apple.product-type.bundle.unit-test' then 'unit-test'
                 when 'com.apple.product-type.bundle.ui-testing' then 'ui-test'
                 else type.split('.').last || 'unknown'
                 end
    { name: target.name, type: type_short }
  end
  targets.each { |t| puts "#{t[:name]} (#{t[:type]})" }

when 'show-files'
  target_names = payload['targets']
  targets = Helpers.resolve_targets(project, target_names, default_to_apps: false)
  if targets.empty?
    warn 'No targets specified or found'
    exit 1
  end

  targets.each do |target|
    puts "# #{target.name}"
    target.build_phases.each do |phase|
      next unless phase.respond_to?(:files)

      phase.files.each do |build_file|
        ref = build_file.file_ref
        next unless ref.respond_to?(:real_path) && ref.real_path

        puts ref.real_path
      end
    end
    puts
  end

when 'find-orphans'
  source_dir = payload.fetch('source_dir')
  source_path = Pathname.new(source_dir)
  source_path = project_dir.join(source_dir) unless source_path.absolute?

  unless source_path.directory?
    warn "Source directory not found: #{source_dir}"
    exit 1
  end

  # Collect all file paths referenced in the project
  project_files = Set.new
  project.files.each do |ref|
    next unless ref.respond_to?(:real_path) && ref.real_path

    project_files.add(ref.real_path.cleanpath.to_s)
  end

  # Find all Swift/ObjC source files in the directory
  extensions = %w[.swift .m .mm .c .cpp .h .hpp]
  orphans = []

  Dir.glob(source_path.join('**/*')).each do |file|
    next unless File.file?(file)
    next unless extensions.include?(File.extname(file))

    abs_path = Pathname.new(file).cleanpath.to_s
    orphans << abs_path unless project_files.include?(abs_path)
  end

  if orphans.empty?
    puts 'No orphaned files found.'
  else
    puts "Orphaned files (#{orphans.count}):"
    orphans.sort.each { |f| puts "  #{f}" }
  end

else
  raise "Unknown action: #{action}"
end
