# INSTRUCTIONS:
# Run this file using " ruby large_files.rb" and put in the inputs  in order to backup large files on backblaze

# make sure the sample.env file has been turned into .env and filled in using information from the backblaze b2 dashboard

# TODO the backblaze gem hasn't been updated in the last 6 months, so doesn't include any API for lifecycle rules. That seems to be the only thing that could essentially be outdated, but might be worth looking into seeing if there are other changes to the API.



# TODO Just might not end up using the gem at all.??


require 'backblaze'
require 'pry'

module LargeFiles
  include Backblaze::B2
  # might not? need to include backblaze
#  def upload_large_files
  
    ## Authorize Account (b2_authorize_account) ##
    
    Backblaze::B2.login(account_id: ENV['ACCOUNT_ID'], application_key: ENV['APPLICATION_KEY'])
    
    ##
    ## b2_list_buckets ##
  def list_and_choose_bucket
    
    #TODO: Eventually want to do something like this:
    #buckets_list_response = Bucket.buckets
    #This would be using the backblaze gem method more directly. However, I wasn't able to figure out how it work exactly offhand, so will have to return to this later if I get the chance. In the meantime:
    buckets_list_response = HTTParty.post("#{Backblaze::B2::Base.base_uri}/b2_list_buckets", 
      body: {accountId: ENV['ACCOUNT_ID']}.to_json,
      headers: Backblaze::B2::Base.headers
    ) #returns an array

    # Basically, to pick a different bucket, replace 0 with the appropriate number. Can do this either using gets.chomp or manually configuring backup_script_template.
    if @chosen_bucket_name == "prompt me"
      puts "Available buckets:"
      buckets_list_response["buckets"].each_with_index do |b, i|
        print i+1 
        puts ") " + b["bucketName"]
      end
      puts "Which Bucket do you want to upload to? (insert number and press enter)" 
      @chosen_bucket_number = gets.chomp.to_i-1

      if @chosen_bucket_number > buckets_list_response["buckets"].length || @chosen_bucket_number < 0 
        #TODO Eventually assign a real error message
        puts "Invalid number: There is no such bucket for that number"
        return
      end
      @chosen_bucket_hash = buckets_list_response["buckets"][@chosen_bucket_number]
    else # I.e., if the @chosen_bucket_name is an actual bucket name:
      buckets_list_response["buckets"].each do |b|
        if @chosen_bucket_name == b["bucketName"]
          @chosen_bucket_hash = b #uckets_list_response["buckets"][@chosen_bucket_index]
          
        end
      end
    end
    
    #This assigns the chosen bucket to a ruby object. I might decide to ultimately not use the backblaze gem as a dependency at all though, and just work directly with the API.
    bucket_object = Bucket.new(bucket_name: @chosen_bucket_hash["bucketName"], bucket_id: @chosen_bucket_hash["bucketId"], bucket_type: @chosen_bucket_hash["bucketType"], account_id: @chosen_bucket_hash["accountId"])
    puts bucket_object.inspect
  end #end of list_and_choose_bucket method

  def specify_file_upload_info
    if @filename_of_upload == "prompt me"
      puts "Available files:"
      #Need to find a way to browse through the directories using Ruby
      filenames_list.each do |f|
        puts f["fileName"]
      end
      puts "Which file do you want to upload?" 
      @filename_of_upload = gets.chomp
    end

    #Might remove this function, or else decided automatically depending on the type of backup.
    puts "Manually decide content type?[y/n] (If answer is not y, it will be assumed that the answer is no)"
    user_response = gets.chomp
    
    if user_response == "y" # or "Y"
      @content_type = gets.chomp
    else 
      @content_type = "b2/x-auto"
    end
  end


  def start_large_file
    response = HTTParty.post("#{Backblaze::B2::Base.base_uri}/b2_start_large_file", 
      body: {
        bucketId: @chosen_bucket_hash["bucketId"],
        fileName: "#{@filename_of_upload}",
        contentType: "#{@content_type}"
        #could also eventually incorporate fileInfo parameter here
      }.to_json,
      headers: Backblaze::B2::Base.headers
    ) 
   puts @chosen_bucket_hash["bucketId"]
   puts response
  end
  def list_filenames

    bucket.file_names.each do |f|
     puts  f.file_name #(or something like this)
    end
  end
end #(of the module)


