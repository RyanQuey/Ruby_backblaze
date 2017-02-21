require_relative './large_files'
include LargeFiles

#Either put in the exact bucket namehere, if you want to specify the bucket, or else put in "prompt me" if you want to be prompted each time you run the script. Make sure to use the correct capitalization and spacingfor the bucket name.
@chosen_bucket_name = ""

# Eventually move all of this code in turn it into helper methods in place in other documents, to keep this more clean.
if @chosen_bucket_name == "prompt me"
  puts "Available buckets:"
  buckets_list.each do |b|
    puts b["bucketName"]
  end
  puts "Which Bucket do you want to upload to?" 
  @chosen_bucket_name = gets.chomp
end

buckets_list_response.each_with_index do |b, i|
  if b["bucketName"] == @chosen_bucket_name
    @chosen_bucket_index = i
  end
end

# Note that this can be a file or a folder
@file_to_upload = 


# Place "large" or "regular" depending on whether or not you are uploading large files or regular files. If you're not sure, see the backblaze documentation on their website.
size_of_files = ""

if size_of_files == "large"
  upload_large_files
elsif size_of_files == "regular"
