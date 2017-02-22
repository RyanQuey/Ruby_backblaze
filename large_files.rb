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
    
    response = HTTParty.post("#{@api_url}/b2_list_buckets", {
      body: {accountId: ENV['ACCOUNT_ID']}.to_json,
      headers: @api_http_headers
    }) #returns an array
    
    # Basically, to pick a different bucket, replace 0 with the appropriate number. Can do this either using gets.chomp or manually configuring backup_script_template.
    if @chosen_bucket_name == "prompt me"
      puts "Available buckets:"
      response["buckets"].each_with_index do |b, i|
        print i+1 
        puts ") " + b["bucketName"]
      end
      puts "Which Bucket do you want to upload to? (insert number and press enter)" 
      @chosen_bucket_number = gets.chomp.to_i-1

      if @chosen_bucket_number > response["buckets"].length || @chosen_bucket_number < 0 
        #TODO Eventually assign a real error message
        puts "Invalid number: There is no such bucket for that number"
        return
      end
      @chosen_bucket_hash = response["buckets"][@chosen_bucket_number]
    else # I.e., if the @chosen_bucket_name is an actual bucket name:
      response["buckets"].each do |b|
        if @chosen_bucket_name == b["bucketName"]
          @chosen_bucket_hash = b 
        end
      end
    end
    
  end #end of list_and_choose_bucket method

  def upload_setup(filename, file_data)
    if @size_of_file == "large"
      #Basically implements b2_start_large_file API call
      response = HTTParty.post("#{@api_url}/b2_start_large_file", 
        body: {
          bucketId: @chosen_bucket_hash["bucketId"],
          fileName: filename,
          contentType: "#{file_data["content_type"]}"
          #could also eventually incorporate fileInfo parameter here
        }.to_json,
        headers: @api_http_headers
      ) 
      @file_id = response["fileId"]
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
    # This array will store the URLs, one for each thread
    @upload_urls.push(response["uploadUrl"])
  end


  def upload_file(filename, file_data)
    if @size_of_file == "large"
      ##Largely following the backblaze official documentation for b2_upload_part

      ##Begin by setting variables
      local_file_size = file_data[:file_object].size
      total_bytes_sent = 0 #Initializes variable as 0. Will eventually total all of the bytes sent for the entire file, totaling all the parts
      bytes_sent_for_part = @minimum_part_size_bytes # this set the default size of the parts
      sha1_of_parts = [] # SHA1 of each uploaded part. You will need to save these because you will need them in b2_finish_large_file.
      part_number = 1 #begins with the 1st part, but that will change as the program runs
      thread_number = 1 #This is the default thread number. Redefined this local variable when the thread number changes, so be sure never to exceed the number_of_threads local variable since that local variable determines how many URLs we have, and we need one URL per thread
      ##Iterate through the file until entire file is finished uploading
      while total_bytes_sent < local_file_size do 

        ##Determine number of bytes to send
        #Basically, if the rest of the file that hasn't been uploaded yet is less than the minimum part size, the last part will only be the size of the rest of the file that hasn't been uploaded yet rather than the minimum part size
        if (local_file_size - total_bytes_sent) < @minimum_part_size_bytes
          bytes_sent_for_part = (local_file_size - total_bytes_sent)
        end

        ## Read file into memory and calculate an SHA1
        file_part_data = File.read(file_data[:file_path], bytes_sent_for_part, total_bytes_sent, mode: "rb")
 #TODO: try this instead to potentially speed things up: 
 #file_part_data = file_data[:file_object].read(bytes_sent_for_part) #This is what is recommended in the documentation: 
 #Need to make sure though that the read method only reads what hasn't already been read, which is what the class method File.read does. But I think what I have your does do that.
        sha1_of_parts.push(Digest::SHA1.hexdigest(file_part_data)) # Adds the SHA 1 of this part onto the sha1_of_parts array

        # Send it over the wire
        uri = URI(@upload_urls[thread_number -1]) # Subtract one in order to get the right index from the sha1_of_parts array       
        header = { 
          "Authorization": "#{@api_http_headers[:Authorization]}",
          "X-Bz-Part-Number":  "#{part_number}",
          "Content-Length": "#{bytes_sent_for_part}", #is the same as the minimum? No distinction at all?
          #Not sure how to figure this one out. Maybe environ variable?
          "X-Bz-Content-Sha1": "#{sha1_of_parts[part_number -1]}" # Subtract one in order to get the right index from the sha1_of_parts array
        }
        response = HTTParty.post(
          "#{uri}", 
          headers: header
        )
        puts response
        #TODO:Eventually want to deal with the possibility of error messages, and redirect or something, just as the backblaze documentation does.
  
        # Prepare for the next iteration of the loop (i.e., for the next part)
        total_bytes_sent += bytes_sent_for_part
        part_number += 1
      end

        #TODO:b2_finish_large_file


    elsif @size_of_file == "regular"
      #TODO: What do I do for regular files?
      b2_upload_file
    end
    
  end

end #(of the module)

