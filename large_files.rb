# INSTRUCTIONS:
# Run this file using " ruby large_files.rb" and put in the inputs  in order to backup large files on backblaze

# make sure the sample.env file has been turned into .env and filled in using information from the backblaze b2 dashboard

# TODO the backblaze gem hasn't been updated in the last 6 months, so doesn't include any API for lifecycle rules. That seems to be the only thing that could essentially be outdated, but might be worth looking into seeing if there are other changes to the API.



# TODO Just might not end up using the gem at all.??


require 'backblaze'
require 'pry'

#module LargeFiles
  include Backblaze::B2
  # might need to include backblaze
#  def upload_large_files
  
    ## Authorize Account (b2_authorize_account) ##
    
    Backblaze::B2.login(account_id: ENV['ACCOUNT_ID'], application_key: ENV['APPLICATION_KEY'])
    
    ##
    ## b2_list_buckets ##
    
    # borrowing from backblaze b2's own documentation, found on their website
    #Backblaze::B2::Base
    
    buckets_list_response = HTTParty.post("#{Backblaze::B2::Base.base_uri}/b2_list_buckets", 
      body: {accountId: ENV['ACCOUNT_ID']}.to_json,
      headers: Backblaze::B2::Base.headers
    ) 
    number_of_buckets = buckets_list_response.length

    # Basically, to pick a different bucket, replace 0 with the appropriate number. Can do this either using gets.chomp or manually configuring backup_script_template.
    chosen_bucket = buckets_list_response["buckets"][0]
    
    bucket = Bucket.new(bucket_name: chosen_bucket["bucketName"], bucket_id: chosen_bucket["bucketId"], bucket_type: chosen_bucket["bucketType"], account_id: chosen_bucket["accountId"])
    puts bucket.file_names
    ##
    ##b2_start_large_file
  
  
    
#  end 
  #
#end


