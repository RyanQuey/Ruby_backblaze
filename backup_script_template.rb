#################
# INSTRUCTIONS:

# -Run this file using "foreman run ruby large_files.rb" and put in the inputs  in order to backup large files on backblaze

# -Make sure the sample.env file has been turned into .env and filled in using information from the backblaze b2 dashboard

# -Set the PATH_TO_UPLOAD environment variable in .env as a string with paths for all the files you want to upload separated by commas, with no spaces in between. The path should start with a / and give the path from a root directory (i.e., absolute path)

# -Set the @bucket_name (see instructions below)
##################

require_relative './helper_methods'
include HelperMethods

## Instructions: Either put in the exact bucket name here, if you want to specify the bucket, or else leave the following line commented out if you want to be prompted each time you run the script. Make sure to use the correct capitalization and spacing for the bucket name.
@bucket_name = "prompt me"

# Will end up being an array filled with hashes, similar to JSON
files_to_upload = []
#This variable is used to set the index
file_number = 0
paths_to_upload = ENV['PATHS_TO_UPLOAD'].split(",")
paths_to_upload.each do |path|
  file_object = File.open(path)
  file_name = path.split("/")[-1]
  file_to_merge = {
    file_name: file_name,
    #content_type: "image/png",
    content_type: "multipart/form-data",
    #content_type: "b2/x-auto",
    file_object: file_object,
    file_path: path
  }
  files_to_upload = files_to_upload.push(file_to_merge)
  file_number += 1
end

## TODO:First, make sure that no write operations are being ran on the folder you are trying to backup. 

#Might try running a shell command instead. If I want to do that, try using Guard::Process or Guard::Kjell
#I could do this to delay running the rest of the program (i.e., put the rest of the program a different Ruby file, and then only run it when there is no writing activity for 30 seconds or whatever on the repository I'm backing up). If I do it this way, 
#Don't try only saving the snapshots with Borg if the virtual machine is still running. Forums speak against this strongly.



authorize_account
## Archive the folder that I'm trying to backup.
# Note: bzip is supposed to compress the folder into a smaller size, but gzip is supposed to be faster, so I'll go with that route since borg is already compressing.
files_to_upload.each_with_index do |f, index|
  if Dir.exists?(f[:file_path]) #checks to see if this is a directory
    #Eliminates the final "/" which is often included in paths for directories
    if f[:file_path][-1] == "/" 
      f[:file_path].chop!
    end
    archive_path = "#{f[:file_path]}" + ".tar.gz" # only take the path where the target file is located, does not include the file_name itself
    # [1, -1] so that removes the first "/", as instructed by tar
    system "tar -czvf #{archive_path} -C / #{f[:file_path][1..-1]}"

    # Overwrite this entry in the files_to_upload 
    new_file_path = "#{f[:file_path]}.tar.gz"
    new_file_object = File.open(new_file_path)
    files_to_upload[index] = {
      file_name: "#{f[:file_name]}.tar.gz",
#      content_type: "b2/x-auto",
      content_type: "multipart/form-data",
#     content_type: "application/gzip",
      file_object: new_file_object,
      file_path: new_file_path
    }
  end
  # Need to pass in the argument like this rather than just as "f", just in case the got overwritten by the archived version
  upload_files(files_to_upload[index])
  
end
