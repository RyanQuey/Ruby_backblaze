require_relative './large_files'
include LargeFiles

#Either put in the exact bucket name here, if you want to specify the bucket, or else leave in "prompt me" if you want to be prompted each time you run the script. Make sure to use the correct capitalization and spacing for the bucket name.

@chosen_bucket_name = "prompt me"
@filename_of_upload = "test_for_upload.txt"
size_of_file = "large"



#Either put in the exact file/folder name here, if you want to specify the file/folder, or else leave in "prompt me" if you want to be prompted each time you run the script. Make sure to use the correct capitalization and spacing for the file/folder name.
# Note that this can be a file or a folder


# Eventually move all of this code in turn it into helper methods in place in other documents, to keep this more clean.

# Place "large" or "regular" depending on whether or not you are uploading large files or regular files. If you're not sure, see the backblaze documentation on their website.

list_and_choose_bucket
specify_file_upload_info



if size_of_file == "large"
  start_large_file
elsif size_of_file == "regular"
end
