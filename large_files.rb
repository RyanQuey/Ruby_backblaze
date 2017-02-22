require 'pry'

#TODO: I might want to do something better in the future, but using this for now, since it is in the template given in the documentation for b2
require 'digest/sha1'

module HelperMethods
  include HTTParty
  
   def authorize_account 
    response = HTTParty.get("https://api.backblazeb2.com/b2api/v1/b2_authorize_account", {
      basic_auth: {
        username: ENV['ACCOUNT_ID'], 
        password: ENV['APPLICATION_KEY']
      }
    })
    @api_url = response['apiUrl'] + "/b2api/v1/"
    @api_http_headers = {
      "Authorization": response['authorizationToken'],
      "Content-Type": "application/json"
    }
    @minimum_part_size_bytes = response['minimumPartSize']
    ##
    ## b2_list_buckets ##
  end

  def list_and_choose_bucket
    
    buckets_list_response = HTTParty.post("#{@api_url}/b2_list_buckets", {
      body: {accountId: ENV['ACCOUNT_ID']}.to_json,
      headers: @api_http_headers
    }) #returns an array
    
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
          @chosen_bucket_hash = b 
        end
      end
    end
    
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
      response = HTTParty.post("#{@api_url}/b2_start_large_file", 
        body: {
          bucketId: @chosen_bucket_hash["bucketId"],
          fileName: "#{@filename_of_upload}",
          contentType: "#{@content_type}"
          #could also eventually incorporate fileInfo parameter here
        }.to_json,
        headers: @api_http_headers
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
    response = HTTParty.post("#{@api_url}/b2_get_upload_part_url", 
      body: {
        fileId: @file_id
      }.to_json,
      headers: @api_http_headers
    ) 
    puts response
    @upload_urls.push(response["uploadUrl"])
  end


  def upload_file
    if @size_of_file == "large"
      ##b2_upload_part
      number_of_parts = 1
      number_of_parts.times do |p|
        additional_header_info = {
          "X-Bz-Part-Number": p,
          #is the same as the minimum?
          "Content-Length": @minimum_part_size_bytes,
          #Not sure how to figure this one out. Maybe environ variable?
          "X-Bz-Content-Sha1": 1
        }
        response = HTTParty.post("#{@api_url}/b2_upload_part", 
          body: {
            fileId: @file_id
          }.to_json,
          headers: @api_http_headers.merge(additional_header_info)
        ) 
        puts response
      end
      b2_finish_large_file
    elsif @size_of_file == "regular"
      #TODO: What do I do for regular files?
      b2_upload_file
    end
    
  end

end #(of the module)

