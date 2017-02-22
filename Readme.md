#  ruby_Backblaze

## Features
-Automatically compiled using gzip if the file to upload is a folder that is already archived.

-Prevents backups from running while the files are being written to and vice a versa.

## Installation and Setup

1) Clone or download this file from github

2) Set up your Backblaze account and create your bucket(s) using their web interface.

3) Manually install the gem "Foreman"

4) Open the main folder (named "ruby_backblaze/") and run "bundle install"

5)  Rename sample.env to ".env", and fill in the environment variables there using the information provided by your backblaze b2 dashboard


## Usage 

Open the main folder (named "ruby_backblaze/") and run "foreman run ruby backup_script_template.rb"

**TODO**
Figure out a way to run multiple threads to upload larger files faster. 


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake rspec` to run the tests.

## Notes on my implementation

Decided not to use credentials_file method given by backblaze gem, but instead using .env

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/RyanQuey/ruby_backblaze. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


