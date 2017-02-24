require 'pry'

#TODO: I might want to do something better in the future, but using this for now, since it is in the template given in the documentation for b2
require 'digest/sha1'

module HelperMethods
  include HTTParty
  
  def upload_files(file)
      list_and_choose_bucket(file)
      @local_file_size = file[:file_object].size
      #sets the variable as an empty array which will be filled up by the call to get_upload_url
      if @local_file_size > @minimum_part_size_bytes # If true, this would be a large upload
        #Put a number here for the number of threads
        number_of_threads = 1
        check_for_unfinished_large_files(file)
        # skips this method if continuing an unfinished upload, since the @file_id from that method would be used instead
        upload_setup(file) if  @file_id == nil
        @upload_urls = []
        number_of_threads.times { |i| get_upload_part_url( file, i+1) } # +1 , or else i will start at 0 rather than 1.
        upload_large_file(file)
        finish_large_file(file)
      else  # For a regular upload
        get_upload_url(file)
        upload_regular_file(file)
      end
  end

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

  def list_and_choose_bucket(file)
    response = HTTParty.post("#{@api_url}/b2_list_buckets", {
      body: {accountId: ENV['ACCOUNT_ID']}.to_json,
      headers: @api_http_headers
    }) 
    handle_response_status_code(file, response)
    if @bucket_name == "prompt me"
      puts "Available buckets:"
      response["buckets"].each_with_index do |b, i|
        print i+1 
        puts ") " + b["bucketName"]
      end
      puts "Which Bucket do you want to upload to? (insert number and press enter)" 
      @chosen_bucket_number = gets.chomp.to_i-1
      # leaves the program. If there is an invalid number  given
      if @chosen_bucket_number > response["buckets"].length || @chosen_bucket_number < 0 
        #TODO Eventually assign a real error message

        puts "Invalid number: There is no such bucket for that number"
        return
      else # if a valid bucket has been chosen
        @chosen_bucket_hash = response["buckets"][@chosen_bucket_number]
        @bucket_name = @chosen_bucket_hash["bucketName"]
      end
    else # I.e., if the bucket was already chosen
      response["buckets"].each do |b|
        if @bucket_name == b["bucketName"]
          @chosen_bucket_hash = b 
        end
      end
    end
  end 

  def check_for_unfinished_large_files(file)
    puts "Finish uploading previously started upload of this file instead?"
    puts "(y/n -- if anything other than 'y' is given, answer is assumed to be 'no'):"
    user_input = gets.chomp
    unless user_input == "y" || user_input == "Y"
      return
    end
    response = HTTParty.post("#{@api_url}/b2_list_unfinished_large_files", 
      body: {
        bucketId: @chosen_bucket_hash["bucketId"],
      }.to_json,
      headers: @api_http_headers
    ) 
    handle_response_status_code(file, response)
    puts "Unfinished files:"
    #only return uploads that are backups of the same file that the user is trying to upload.
    response["files"].select! { |f| f["fileName"] == file[:file_name]}
    response["files"].each_with_index do |f, i|
      print i+1 
      puts ") " + f["fileName"]
    end

    #Select which upload to finish
    puts "Which upload do you want to finish? (insert number of file to finish or 'n' to upload this file from scratch)" 
    @chosen_file_number = gets.chomp
    return if @chosen_file_number == "n"
    # Just to make sure that an erroneous numbers is not put in
    if response["files"].length >= @chosen_file_number.to_i-1
      #TODO: might not need the following instance variable; but might need it, so leave it for now.
      #@file_to_finish = response["files"][@chosen_file_number.to_i-1] # this will be a hash with various metadata for the file
      @file_id = response["files"][@chosen_file_number.to_i-1]["fileId"]
      list_already_uploaded_parts(file)
      # No need to change any other variable, since the bucket will be the same in the filename will already be the same.
    else
      puts "continuing with new upload..."
    end
    
  end

  def upload_setup(file)
    #Basically implements b2_start_large_file API call
    response = HTTParty.post("#{@api_url}/b2_start_large_file", 
      body: {
        bucketId: @chosen_bucket_hash["bucketId"],
        fileName: file[:file_name],
        contentType: "#{file["content_type"]}"
        #could also eventually incorporate fileInfo parameter here
      }.to_json,
      headers: @api_http_headers
    ) 
    @file_id = response["fileId"]
    handle_response_status_code(file, response)
  end

  def get_upload_url(file) #for regular files
    response = HTTParty.post("#{@api_url}/b2_get_upload_url", 
      body: {
      bucketId: @chosen_bucket_hash["bucketId"]
      }.to_json,
      headers: @api_http_headers
    ) 
    # Keep this in array, in order to have continuity with the large file uploads
    @upload_urls = [response["uploadUrl"]]
    handle_response_status_code(file, response)
  end

  #Should receive the thread_number argument when this method is called, but if it does not, default to thread number 1.
  #TODO: Might not need this variable thread_number at all
  def get_upload_part_url( file, thread_number=1) #for large files
    response = HTTParty.post("#{@api_url}/b2_get_upload_part_url", 
      body: {
        fileId: @file_id
      }.to_json,
      headers: @api_http_headers
    ) 
    # This array will store the URLs, one for each thread
    @upload_urls.push(response["uploadUrl"])
    handle_response_status_code(file, response)
  end

  def upload_regular_file(file)
    ##Largely following the backblaze official documentation for b2_upload_file

    ##Begin by setting variables
    ## Read file into memory and calculate an SHA1
    file_content = File.read(file[:file_path])
    #TODO: try this instead to potentially speed things up: 
    #file = file[:file_object].read 
    #Currently using what is recommended in the documentation 
    @sha1_of_parts = [Digest::SHA1.hexdigest(file_content)] # Keeping this as an array in owner to have continuity with uploading large files

    ## Send it over the wire
    uri = URI(@upload_urls[0])  
    #TODO: Not sure if this encodes correctly or not
    encoded_file_name = file[:file_name].encode('utf-8')
    header = { 
      "Authorization": "#{@api_http_headers[:Authorization]}",
      "X-Bz-File-Name":  "#{encoded_file_name}",
      "Content-Type": "#{file[:content_type]}",
      "Content-Length": "#{@local_file_size}", #is the same as the minimum? No distinction at all?
      "X-Bz-Content-Sha1": "#{@sha1_of_parts[0]}" # Subtract one in order to get the right index from the sha1_of_parts array
    }
 binding.pry
    response = HTTParty.post(
      "#{uri}", 
      headers: header,
      body: file_content,
      debug_output: $stdout
    )
    puts response
    handle_response_status_code(file, response)
    #TODO:Eventually want to deal with the possibility of error messages, and redirect or something, just as the backblaze documentation does.
  end

  def upload_large_file(file)
    ##Largely following the backblaze official documentation for b2_upload_part

    ##Begin by setting variables
    total_bytes_sent = 0
    bytes_sent_for_part = @minimum_part_size_bytes # this set the default size of the parts, in what will be sent for this part, by the time this method is finished.
    @sha1_of_parts = []
    part_number = 1 #begins with the 1st part, but that will change as the program runs
    thread_number = 1 #This is the default thread number. Redefined this local variable when the thread number changes, so be sure never to exceed the number_of_threads local variable since that local variable determines how many URLs we have, and we need one URL per thread
    ##Iterate through the file until entire file is finished uploading
    while total_bytes_sent < @local_file_size do 
      ##Determine number of bytes to send
      #Basically, if the rest of the file that hasn't been uploaded yet is less than the minimum part size, the last part will only be the size of the rest of the file that hasn't been uploaded yet rather than the minimum part size
      if (@local_file_size - total_bytes_sent) < @minimum_part_size_bytes
        bytes_sent_for_part = (@local_file_size - total_bytes_sent)
      end
      ## Read file into memory and calculate an SHA1
      file_part_data = File.read(file[:file_path], bytes_sent_for_part, total_bytes_sent, mode: "rb")
      #TODO: try this instead to potentially speed things up: 
      #file_part_data = file[:file_object].read(bytes_sent_for_part) 
      #Currently using what is recommended in the documentation 
      #Need to make sure though that the read method only reads what hasn't already been read, which is what the class method File.read does. But I think what I have your does do that.
       @sha1_of_parts.push(Digest::SHA1.hexdigest(file_part_data)) # Adds the SHA 1 of this part onto the sha1_of_parts array
      # Send it over the wire
      uri = URI(@upload_urls[thread_number -1]) # Subtract one in order to get the right index from the sha1_of_parts array       
      header = { 
        "Authorization": "#{@api_http_headers[:Authorization]}",
        "X-Bz-Part-Number":  "#{part_number}",
        "Content-Length": "#{bytes_sent_for_part}", #is the same as the minimum? No distinction at all?
        "X-Bz-Content-Sha1": "#{@sha1_of_parts[part_number -1]}" # Subtract one in order to get the right index from the sha1_of_parts array
      }
      response = HTTParty.post(
        "#{uri}", 
        headers: header,
        body: file_part_data,
        debug_output: $stdout
      )
      puts response
      handle_response_status_code(file, response)
      #TODO:Eventually want to deal with the possibility of error messages, and redirect or something, just as the backblaze documentation does.

      # Prepare for the next iteration of the loop (i.e., for the next part)
      total_bytes_sent += bytes_sent_for_part
      part_number += 1
    end

  end

  def finish_large_file(file)
    #TODO:might use large_file_sha1 as the documentations suggests
    
    response = HTTParty.post("#{@api_url}/b2_finish_large_file", 
      body: {
        fileId: @file_id,
        partSha1Array: @sha1_of_parts
      }.to_json,
      headers: @api_http_headers
    ) 
    puts response
    handle_response_status_code(file, response)
  end


  private

  def list_already_uploaded_parts(file)
    response = HTTParty.post("#{@api_url}/b2_list_parts", 
      body: {
        fileId: @file_id,
      }.to_json,
      headers: @api_http_headers
    ) 
    puts "Already uploaded parts:"
    puts response  
    handle_response_status_code(file, response)
  end

  def cancel_large_file

  end

  def handle_response_status_code(file, http_response)
    case http_response["status"]
    when 200
      puts "All good for " + caller[0][/`.*'/][1..-2].to_s
    when 404
      puts "O noes not found for " + caller[0][/`.*'/][1..-2].to_s
    when 400..401
      puts response
    when 500...600
      puts response
      puts  "ZOMG ERROR #{http_status} for " + caller[0][/`.*'/][1..-2].to_s
      puts "Try again...?"
      user_response = gets.chomp 
      if user_response == "y" || user_response == "Y"
        authorize_account
        upload_files(file)
      end
    end 
  end 
end #(of the module)

