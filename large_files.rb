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

  def specify_file
    #TODO Need to come up with file names list, using the Ruby Dir and File classes.
    puts "Available files:"
    #Need to find a way to browse through the directories using Ruby
    puts "Which file do you want to upload?" 
    @filename_of_upload = gets.chomp
  end

  def upload_setup 
    if @size_of_file == "large"
      #Basically implements b2_start_large_file API call
      response = HTTParty.post("#{Backblaze::B2::Base.base_uri}/b2_start_large_file", 
        body: {
          bucketId: @chosen_bucket_hash["bucketId"],
          fileName: "#{@filename_of_upload}",
          contentType: "#{@content_type}"
          #could also eventually incorporate fileInfo parameter here
        }.to_json,
        headers: Backblaze::B2::Base.headers
      ) 
      @file_id = response["fileId"]
      puts @file_id
    elsif @size_of_file == "regular"
      #TODO: What do I do for regular files?
    end
  end

  #Should receive the thread_number argument when this method is called, but if it does not, default to thread number 1.
  #TODO: Might not need this variable thread_number at all
  def get_upload_url(thread_number=1)
    response = HTTParty.post("#{Backblaze::B2::Base.base_uri}/b2_get_upload_part_url", 
      body: {
        fileId: @file_id
      }.to_json,
      headers: Backblaze::B2::Base.headers
    ) 
    puts response
    @upload_urls.push(response["uploadUrl"])
  end

end #(of the module)


