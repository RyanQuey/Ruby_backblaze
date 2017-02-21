# Backblaze

The Backblaze ruby gem is an implementation of the [Backblaze B2 Cloud Storage API](https://www.backblaze.com/b2/docs/). In addition to simplifying calls, it also implements an object oriented structure for dealing with files. Calling the api through different objects will not cause each to get updated. Always assume that data retrieved is just a snapshot from when the object was retrieved.

## Installation

1) Clone or download this file from github

2) Set up your Backblaze account and create your bucket(s) using their web interface.

3) Manually install the gem "Foreman"

4) Open the main folder (named "ruby_backblaze/") and run "bundle install"

5)  Rename sample.env to ".env", and fill in the environment variables there using the information provided by your backblaze b2 dashboard




## Usage 

Open the main folder (named "ruby_backblaze/") and run "foreman run ruby ...", depending on the type of files you want to upload.

For large files, including backup files, use large_files.rb. Just put the entire backup into a single folder, and designate that folder as the upload file. (Might need to be compressed/archived?)

**TODO**
Figure out a way to run multiple threads to upload larger files faster. 


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake rspec` to run the tests.

## Notes on my implementation

Decided not to use credentials_file method given by backblaze gem, but instead using .env

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/RyanQuey/ruby_backblaze. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
