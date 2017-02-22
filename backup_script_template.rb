# INSTRUCTIONS:
# Run this file using " ruby large_files.rb" and put in the inputs  in order to backup large files on backblaze

# make sure the sample.env file has been turned into .env and filled in using information from the backblaze b2 dashboard

# TODO the backblaze gem hasn't been updated in the last 6 months, so doesn't include any API for lifecycle rules. That seems to be the only thing that could essentially be outdated, but might be worth looking into seeing if there are other changes to the API.

require "httparty"
require_relative './large_files'
include HelperMethods

#Either put in the exact bucket name here, if you want to specify the bucket, or else leave in "prompt me" if you want to be prompted each time you run the script. Make sure to use the correct capitalization and spacing for the bucket name.

@chosen_bucket_name = "prompt me"

#Do the same here, with @filename_of_upload
@filename_of_upload = "test_for_upload.txt" #make the default "prompt me"

#Unless you want to manually enter the content type, leave this alone and backblaze will determine the content type automatically.
@content_type = "b2/x-auto"

#Put "regular" for regular uploads, or "large" for large uploads (see backblaze documentation for which to use)
@size_of_file = "large"

#Put a number here for the number of threads
number_of_threads = 1

#Either put in the exact file/folder name here, if you want to specify the file/folder, or else leave in "prompt me" if you want to be prompted each time you run the script. Make sure to use the correct capitalization and spacing for the file/folder name.
# Note that this can be a file or a folder


# Eventually move all of this code in turn it into helper methods in place in other documents, to keep this more clean.

# Place "large" or "regular" depending on whether or not you are uploading large files or regular files. If you're not sure, see the backblaze documentation on their website.

authorize_account
list_and_choose_bucket
specify_file if @filename_of_upload == "prompt me"
upload_setup 
@upload_urls = []
number_of_threads.times { |i| get_upload_url(i+1) }
upload_file
