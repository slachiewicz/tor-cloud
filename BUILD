Installation:

	0) Edit /etc/apt/sources.list to include multiverse
	1) Install ec2-api-tools and git-core on your laptop or build machine
	2) If the setup of openjdk-6-jre-headless is giving you a headache (e.g. crashing the instance), try using the 64-bit Ubuntu image instead.
	3) Clone https://git.torproject.org/tor-cloud.git
	4) Get the private keys (pk.cert and cert.pem) from Amazon and put them somewhere safe
	5) Run the following two commands to make sure the system knows about the private keys:

		# export EC2_PRIVATE_KEY=/path/to/pk.cert
		# export EC2_CERT=/path/to/cert.pem

	1) Test that ec2-api-tools is working:
		root@inf0:~/Tor-Cloud# ec2-describe-regions 
		REGION  eu-west-1       ec2.eu-west-1.amazonaws.com
		REGION  us-east-1       ec2.us-east-1.amazonaws.com
		REGION  ap-northeast-1  ec2.ap-northeast-1.amazonaws.com
		REGION  us-west-1       ec2.us-west-1.amazonaws.com
		REGION  ap-southeast-1  ec2.ap-southeast-1.amazonaws.com

	4) Create Generate private keys for each region. For each key
	   generated, save it in keys/:
	
		# ec2-add-keypair --region us-east-1 tor-cloud-us-east-1
		# ec2-add-keypair --region us-west-1 tor-cloud-us-west-1
		# ec2-add-keypair --region us-west-1 tor-cloud-eu-west-1
		# ec2-add-keypair --region us-west-1 tor-cloud-ap-northeast-1
		# ec2-add-keypair --region us-west-1 tor-cloud-ap-southeast-1


		for example: ec2-add-keypair --region us-east-1 tor-cloud-east-1
		and save the key in: ~/keys/tor-cloud-east-1.pem, don't forget to run chmod 600 ~/keys/*

		Your folder should look like this:
		root@inf0:~/Tor-Cloud# ls /home/architect/keys/ -lh
		-rw------- 1 root root 1.7K 2011-09-12 19:11 tor-cloud-ap-northeast-1.pem
		-rw------- 1 root root 1.7K 2011-09-12 19:13 tor-cloud-ap-southeast-1.pem
		-rw------- 1 root root 1.7K 2011-09-12 19:14 tor-cloud-eu-west-1.pem
		-rw------- 1 root root 1.7K 2011-09-12 19:09 tor-cloud-us-east-1.pem
		-rw------- 1 root root 1.7K 2011-09-12 19:09 tor-cloud-us-west-1.pem


	

	5) Create a Security Group called "tor-cloud-build" and allow SSH inbound traffic.

	6) You are now ready to build Bridge AMIs:
		For example, to build in "ap-southeast-1" region run:
		./build.sh bridge ap-southeast-1 /home/architect/keys/tor-cloud-ap-southeast-1.pem tor-cloud-ap-southeast-1

	7) The last thing the build.sh will spit out is the region and the AMI ID:

		ec2-describe-snapshots --region us-east-1
		IMAGE   ami-5799503e

	8) Before other people can launch it, make sure you make it
	   public in AWS:

		- Images, AMIs, right clic, edit permissions, set to public



	TIP: You can run the build command for all the regions at the same time. Use screen or & to send the process to background!

	
		

		

		
