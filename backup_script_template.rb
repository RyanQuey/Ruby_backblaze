#################
# INSTRUCTIONS:

# -Run this file using "ruby large_files.rb" and put in the inputs  in order to backup large files on backblaze

# -Make sure the sample.env file has been turned into .env and filled in using information from the backblaze b2 dashboard

# -Set the PATH_TO_UPLOAD environment variable in .env as a string with paths for all the files you want to upload separated by commas, with no spaces in between. The path should start with a / and give the path from a root directory (i.e., absolute path)

# -Set the @chosen_bucket_name (see instructions below)
##################

require "httparty"
require_relative './helper_methods'
include HelperMethods




#Either put in the exact bucket name here, if you want to specify the bucket, or else leave in "prompt me" if you want to be prompted each time you run the script. Make sure to use the correct capitalization and spacing for the bucket name.
@chosen_bucket_name = "prompt me"

#Will end up being an array filled with hashes, similar to JSON
files_to_upload = {}
#This variable is used to set the index
file_number = 0
paths_to_upload = ENV['PATHS_TO_UPLOAD'].split(",")
paths_to_upload.each do |path|
  file_object = File.open(path)
  filename = path.split("/")[-1]
  file_to_merge = {
    #TODO:might make the keys into symbols instead of strings?
    filename =>  {
        content_type: "b2/x-auto",
        file_object: file_object,
        file_path: path
    }
  }
  files_to_upload = files_to_upload.merge(file_to_merge)
  file_number += 1
end

## TODO:First, make sure that no write operations are being ran on the folder you are trying to backup. 

#Might try running a shell command instead. If I want to do that, try using Guard::Process or Guard::Kjell
#I could do this to delay running the rest of the program (i.e., put the rest of the program a different Ruby file, and then only run it when there is no writing activity for 30 seconds or whatever on the repository I'm backing up). If I do it this way, 
#Don't try only saving the snapshots with Borg if the virtual machine is still running. Forums speak against this strongly.



## TODO:Next, archive the folder that I'm trying to backup.
#bzip is supposed to compress the folder into a smaller size, but gzip is supposed to be faster, so I'll go with that route since borg is already compressing.

a = 1
files_to_upload.each_with_index do |(filename, file_data), index|
  if Dir.exists?(file_data[:file_path]) #checks to see if this is a directory
    #Eliminates the final "/" which is often included in paths for directories
    if file_data[:file_path][-1] == "/" 
      file_data[:file_path].chop!
    end
    archive_path = "#{file_data[:file_path]}" + ".tar.gz" # only take the path where the target file is located, does not include the filename itself
    # [1, -1] so that removes the first "/", as instructed by tar
    system "tar -czvf #{archive_path} -C / #{file_data[:file_path][1..-1]}"
    # Overwrite this entry in the files_to_upload hash
    new_file_path = "#{file_data[:file_path]}.tar.gz"
    new_file_object = File.open(new_file_path)
    files_to_upload[filename] =  {
      content_type: "b2/x-auto",
      file_object: new_file_object,
      file_path: new_file_path
    }
    new_filename = file_data[:file_path].split("/")[-1]
    files_to_upload.keys[index] = new_filename
  end

  # Sets the file size. Must be done after determining whether or not archiving is necessary. Note: size is in bytes
  
end
files_to_upload.each do |key, value|
  authorize_account
  list_and_choose_bucket
  @local_file_size = value[:file_object].size
  #sets the variable as an empty array which will be filled up by the call to get_upload_url
  if @local_file_size > @minimum_part_size_bytes # If true, this would be a large upload
    #Put a number here for the number of threads
    number_of_threads = 1
    check_for_unfinished_large_files(key, value)
    # skips this method if continuing in unfinished upload, since the @file_id from that method would be used instead
    upload_setup(key, value) unless @file_id == nil
    @upload_urls = []
    number_of_threads.times { |i| get_upload_part_url(i+1) }
    upload_large_file(key, value)
    finish_large_file
  else  # This would then be a regular upload
    # Probably would leave number of threads as one?
    get_upload_url
    upload_regular_file(key, value)
  end
end
