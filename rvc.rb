# This is the main class of the revision control system
# Inside I have implemented all the main commands:
# add(filename): prepare this file for commit
# commit(message): commit the modified or added files to the repository
# status: prints the status of the files M--> modified, A--> added for commit, ? --> not added for commit
# log: prints the log.txt file inside the current branch folder
# revert(version): reverts all the files to the specified versionn
# branch(branch_name): creates a new branch or changes the current branch name to the specified branch
# checkout(filename, version): checks out the filename with the given version from the repository

class RVC
	# member functions that saves the current directory, version number, current branch name,
	# current branch directory and previous directory
	attr_reader	:currentDir ,:version ,:curbranch, :branch_dir, :prev_dir
	
	# This is called when a new object of type RVC is created
	def initialize()
		# saves the current directory in @currentDir
		@currentDir = Dir.getwd

		# if the repository has not been created yet create one
		if !directory_exists?(@currentDir+"/repository")
			# set the current branch to main and the version to 0 because the repository has just been created
			@curbranch = "main"
			@version = 0
			# create the repository directory
			Dir.mkdir(@currentDir+"/repository", 0700)
			# create the current branch folder with name main
			@branch_dir = @currentDir+"/repository/" + @curbranch
			Dir.mkdir(@branch_dir, 0700)
			# creates a new file in the repository which saves the name of the current branch and the versionn number
			initialize_files(@currentDir + "/repository", "_currentBranch.txt", "main 0")
			# create the branches file that will keep the information of all the branches
			initialize_files(@currentDir + "/repository","_branches.txt", "main 0")
			# initializes the log.txt file
			initialize_files(@branch_dir,"log.txt", "")
		else
			# read the current branch file
			data = read_file(@currentDir + "/repository", "_currentBranch.txt")
			data = data.split(' ')
			# set the @curbranch to the first element of the array
			@curbranch = data[0]
			# set the @version to the second element of the array
			@version = data[1].to_i
			# set the current branch directory
			@branch_dir = @currentDir + "/repository/" + @curbranch
		end
	end

	# Prepares the filename to be added for the commit, It checks if the file exists in the repository
	# and if it does than it notifies the user otherwise if it doesnt exist it will create a temp file
	# with filename: "@"+file until the commit command is called
	def add(filename, type)
		file = filename + type
		if(file == __FILE__)
			puts "> Can't add the programs file!!!"
			return
		end
		if @version == 0
			if !does_file_exist?(@currentDir, '@'+file)
				initialize_files(@currentDir, '@'+file, read_file(@currentDir, file))
				puts "> File #{file} was added succesfully. Ready for commit!!!"
			else
				puts "> File #{file} has already been added for commit!!!"
			end
			return
		end

		if is_in_repo?(filename)
			puts "> File #{file} already exist in the repository"
		else
			if !does_file_exist?(@currentDir, '@'+file)
				initialize_files(@currentDir, '@'+file, read_file(@currentDir, file))
				puts "> File #{file} was added succesfully. Ready for commit!!!"
			else
				puts "> File #{file} has already been added for commit!!!!"
			end
			return
		end
	end

	# Commits the added files and the modified files in the current branch of the repository
	# Adds a message to the log file
	# Updates the "_currentBranch.txt" and the "_branches.txt"
	def commit(message)
		# creates an array of files that are ready for commit
		ready_for_commit = Dir.glob("@*")
		puts "Ready for commit: #{ready_for_commit}"
		# parse the files and check if this are new files or they already exist in the repo
		if @version == 0
			if (ready_for_commit.length < 1)
			 	puts "> Nothing to commit!!!!"
			 else
				@version += 1;
				prepare_log(message, ready_for_commit)
				commit_helper_added(ready_for_commit)
				puts "> The commit was succesfull version #{@version}"
			end
		else
			# gets the lost of the modified files
			modified_files = get_modified_files_list();
			if(modified_files.length > 0 && ready_for_commit.length > 1)
				@version += 1;
				modified_files += ready_for_commit
				prepare_log(message, modified_files)
				commit_helper_modified(modified_files)
				commit_helper_added(ready_for_commit)
				puts "> The commit was succesfull version #{@version}"
			elsif(ready_for_commit.length > 0)
				@version += 1;
				prepare_log(message, ready_for_commit)
				commit_helper_added(ready_for_commit)
				puts "> The commit was succesfull version #{@version}"
			elsif(modified_files.length > 0)
				@version += 1;
				prepare_log(message, modified_files)
				commit_helper_modified(modified_files)
				puts "> The commit was succesfull version #{@version}"
			else
				puts "> Nothing to commit!!!!"
			end
		end
	end

	# helper function that commits the files that are in ready_for_commit array
	def commit_helper_added(ready_for_commit)
		ready_for_commit.each do |file|
			type = File.extname(file)
			file.slice!('@')
			file.slice!(type)
			initialize_files(@branch_dir , set_filename_in_rep(file, type) , read_file(@currentDir, file + type))
		end
		# updates the information in the currentBranch file and the branches file
		update_currentBranchfile()
		update_branches()
		delete_ready_for_commitfiles()
	end

	# helper function that commits the files that are in modified_files array
	def commit_helper_modified(modified_files)
		modified_files.each do |file|
			type = File.extname(file)
			file.slice!(type)
			puts file + " -> " + set_filename_in_rep(file, type)
			initialize_files(@branch_dir , set_filename_in_rep(file, type) , read_file(@currentDir, file + type))
		end
		update_currentBranchfile()
		update_branches()
		delete_ready_for_commitfiles()
	end

	# reverts the files in the current branch to the specified version
	# updates the log file
	# updates the "_currentBranche.txt" and "_branches.txt"
	def revert(version)
		Dir.open(@branch_dir).each do |file|
			if(!file.start_with?('.'))
				# parse the file name
				type = File.extname(file)
				file.slice!(type)
				filename = file.split('&')
				if(filename[1].to_i > version.to_i)
					Dir.chdir(@branch_dir)
					File.delete(file+type)
					Dir.chdir(@currentDir)
				end

			end
		end
		@version = version.to_i
		update_currentBranchfile()
		update_branches()
		update_log(version)
	end

	# checks out the specified file with the specified version
	def checkout(filename, version)
		Dir.open(@branch_dir).each do |file|
			if(!file.start_with?('.'))
				# prase the file name
				type = File.extname(file)
				file.slice!(type)
				tokens = file.split('&')
				if(filename.start_with?(tokens[0]) && tokens[1].to_i == version.to_i)
					puts ">Checking out #{filename} version #{version}"
					# update the file in current dir
					write_file(@currentDir, filename, read_file(@branch_dir, file+type))
					return
				end
			end
		end
		puts "> File #{filename} with version #{version} not found in repository. Try another version!"
	end

	# reads the "log.txt" file in the current branch directory and prints the data in the stdin
	def log()
		puts "> The current branch is #{@curbranch}"
		data = read_file(@branch_dir, "log.txt")
		print data
	end

	# writes the message in the "log.txt"
	def write_log(message)
		file = File.open(@branch_dir + '/log.txt', 'a')
		file.write(message)
		file.close
	end

	# prepares the log message by adding the version number, files and time
	def prepare_log(message, files)
		data = ">------------------------------------ \n"
		data += "Message: #{message} \n" 
		data += "Version: #{@version} \n"
		data += "Files: \n"
		files.each do |file|
			puts file
			if(file.start_with?('@'))
				file.slice!('@')
			end
			data += file + "\n"
		end
		time = Time.new
		data += "Time #{time.strftime("%Y-%m-%d %H:%M:%S")} \n"
		data += "------------------------------------ <\n"
		#puts data
		write_log(data)
	end

	# updates the log file 
	# this function is called by the revert function
	# it will remove all the log messages that are greater than the specified version
	def update_log(version)
		data = read_file(@branch_dir, "log.txt")
		data = data.split('<')
		index = 0
		newData = Array.new
		while index < version.to_i && index < data.length 
			newData.push(data[index])
			index += 1
		end
		write_file(@branch_dir, "log.txt", newData.join('<'))
	end

	# prints the status of the file, it checks if the file is modified, or has been added for commit,
	# or none of those
	def status()
		modified_files = get_modified_files_list
		ready_for_commit = Dir.glob("@*")
		Dir.open(@currentDir).each do |file|
			if(modified_files.include?(file))
				puts file + ' --- M'
			elsif(ready_for_commit.include?('@'+file))
				puts file + ' --- A'
			else
				type = File.extname(file)
				file.slice!(type)
				if !is_in_repo?(file)
					file = file + type
					puts file + ' --- ?' if(!file.start_with?('@') && !directory_exists?(file) && !file.start_with?('.') && file != __FILE__)
				end
			end
		end
	end

	# returns the list of files that has been modified since the last time the files has beend modified 
	def get_modified_files_list()
		modified_files = Array.new
		Dir.open(@currentDir).each do |file|
			if !file.start_with?('@') && !file.start_with?('.')
				type = File.extname(file)
				file.slice!(type)
				if is_in_repo?(file)
					file_in_repository = get_file_from_rep(file);
					file = file+type;
					if !are_identical?(file, file_in_repository)
						modified_files.push(file)
					end
				end
			end
		end
		return modified_files
	end

	# returns true if file1 and file2 are identical
	def are_identical?(file1, file2)
		#puts "Comparing #{file1} with #{file2}"
		data1 = read_file(@currentDir, file1)
		data2 = read_file(@branch_dir, file2)
		return (data1 == data2)
	end

	# deletes the temp files that start with '@'
	def delete_ready_for_commitfiles()
		ready_for_commit = Dir.glob("@*")
		ready_for_commit.each do |file|
			File.delete(file)
		end
	end

	# returns true if directory exists
	def directory_exists?(directory)
  		File.directory?(directory)
	end
	
	# creates a new branch if the branch doesnt already exist
	# if the branch exists just change the current branch name
	def branch(brname)
		@prev_dir = @branch_dir
		@curbranch = brname
		@branch_dir = @currentDir + "/repository/" + @curbranch
		if(!directory_exists?(@branch_dir))
			Dir.mkdir(@branch_dir, 0700)
		end
		update_currentBranchfile()
		if (!branch_exists?(brname))
			add_new_branch();
			puts "> Create branch #{brname}"
		else
			if (has_branch_changed?(@prev_dir, @branch_dir))
				puts "There were some modifications made to the prev branch do you want to apply this changes to #{curbranch} y/n ? "
				if (STDIN.gets.chomp == "y")
					copy_files()
					puts "> Branch #{curbranch} was updated succesfully"
				end
			end
			puts "> Current branch changed to #{brname}"
		end
	end

	# helper function that updates te current branch file
	def update_currentBranchfile()
		data = read_file(@currentDir + "/repository", "_currentBranch.txt")
		data = data.split(' ')
		data[0] = @curbranch;
		data[1] = @version;
		write_file(@currentDir + "/repository", "_currentBranch.txt", data.join(' '))
	end

	# add a new branch in the repository
	# creates a new directory with the @curbranch name,
	# updates the "_branches.txt" file
	def add_new_branch()
		data = read_file(@currentDir + "/repository", "_branches.txt")
		data = data.split('\n')
		newB = Array.new
		newB[0] = @curbranch
		newB[1] = @version
		data.push(newB.join(' '))
		path = @currentDir + "/repository"
		write_file(path, "_branches.txt", data.join("\n"))
		Dir.open(@prev_dir).each do |file|
			if(!file.start_with?('.'))
				write_file(@branch_dir, file, read_file(@prev_dir, file))
			end
		end
	end

	def has_branch_changed?(path1, path2)
		num_files1 = Dir.open(path1).count
		num_files2 = Dir.open(path2).count
		return (num_files1 != num_files2)
	end

	def copy_files()
		Dir.open(@prev_dir).each do |file|
			write_file(@branch_dir, file, read_file(@prev_dir, file))
		end
	end
	def branch_exists?(branchname)
		data = read_file(@currentDir + "/repository", "_branches.txt")
		data = data.split("\n")
		data.each do |d|
			d = d.split(' ')
			#puts "#{d[0]} # #{d[1]}"
			if(d[0] == branchname)
				return true
			end
		end
		return false
	end

	def update_branches()
		data = read_file(@currentDir + "/repository", "_branches.txt")
		data = data.split('\n')
		a = Array.new
		data.each do |d|
			d = d.split(' ')
			if(d[0] == @curbranch)
				d[1] = @version
			end
			a.push(d.join(' ')) 
		end
		write_file(@currentDir + "/repository", "_branches.txt", a.join('\n'))
	end

	# Helper functions in modifying files and directories
	# creates new files to the specified path and writes the given value to them
	def initialize_files(path, filename, value)
		if directory_exists?(path)
			Dir.chdir(path)
			f = File.new(filename, "w+")
			f.write(value)
			f.close
			Dir.chdir(@currentDir)
		else
			puts "The path doesnt exist!!!!"
		end
	end

	# checks if a file with the specified name exist in the given path
	def does_file_exist?(path, filename)
		if (directory_exists?(path))
			# get inside the specified path
			Dir.chdir(path)
			# check if a file exist
			exist = File.file?(filename) ? true : false
			# go back to the main directory
			Dir.chdir(currentDir)
			return exist
		end
		return false
	end

	def is_in_repo?(filename)
		Dir.open(@branch_dir).each do |file|
			if(file.start_with?(filename))
				return true
			end
		end
		return false
	end

	def read_file(path, filename)
		if(does_file_exist?(path, filename))
			file = File.open(path + '/' + filename, 'r')
			data = file.read
			file.close
			return data
		end
		return "Nothing"
	end
	
	def write_file(path, filename, data)
		file = File.open(path + '/' + filename, 'w+')
		file.write(data)
		file.close
	end

	def set_filename_in_rep(filename, type)
		return filename + '&' + @version.to_s + type
	end

	def get_file_from_rep(filename)
		files = Array.new
		Dir.open(@branch_dir).each do |file|
			if(file.start_with?(filename))
				files.push(file)
			end
		end
		latestversion = 0
		latestfile = 'test'
		files.each do |file|
			file = file.split('&')
			if(file[1].to_i > latestversion)
				latestversion = file[1].to_i;
				latestfile = file.join('&')
			end
		end
		return latestfile
	end

	def is_file_in_repository?(filename, type)
		file_in_repos = get_file_from_rep(filename)
		return does_file_exist?(@branch_dir, filename)
	end

end


# MAIN PROGRAM
rvc = RVC.new
inputNumber = ARGV.length
if inputNumber >= 2
	if ARGV[0] == 'add'
		ARGV.each do |filename|
			if File.file?(filename)
				file = filename.split('.')[0]
				rvc.add(file, File.extname(filename))
			elsif filename != 'add'
				puts ">The file #{filename} doesnt exist in the current folder!!!"
			end
		end
	elsif ARGV[0] == 'commit'
		rvc.commit(ARGV[1])
	elsif ARGV[0] == 'branch'
		rvc.branch(ARGV[1])
	elsif ARGV[0] == 'revert'
		rvc.revert(ARGV[1])
	elsif ARGV[0] == 'checkout'
		if ARGV[2] != ""
			rvc.checkout(ARGV[1], ARGV[2])
		else
			rvc.checkout(ARGV[1], rvc.version)
		end
	end
elsif ARGV[0] == 'status'
	rvc.status()
elsif ARGV[0] == 'log'
	rvc.log()
end