## Create self signed certificate

- Generate the key pair

        | keytool -genkey -keyalg RSA -alias selfsigned -keystore keystore.jks -storepass password -validity 360 -keysize 2048


- Extract Certificate

        | keytool -export -rfc -keystore keystore.jks -storepass password -alias selfsigned -file mycert.pem

- Extract Cert Key to PEM format

        | keytool -importkeystore -srcstoretype JKS -srckeystore keystore.jks -deststoretype PKCS12 -destkeystore mykey.der
        | openssl pkcs12 -in mykey.der -nodes -out mykey.pem

## For installation.

- Check the publishers

        | pkg publisher
        solaris                               origin   online   http://pkg.oracle.com/solaris/release/

- Add puppetlabs.com as a publisher

        | pkg set-publisher -p http://solaris-11-ips-repo.acctest.dc1.puppetlabs.net puppetlabs.com

- Check that we have it correct

        | pkg publisher
        solaris                               origin   online   http://pkg.oracle.com/solaris/release/
        puppetlabs.com                        origin   online   http://solaris-11-ips-repo.acctest.dc1.puppetlabs.net/

- Verify that puppetlabs.com was set correctly,

        | pkg publisher puppetlabs.com
                Publisher: puppetlabs.com
                    Alias:
               Origin URI: http://solaris-11-ips-repo.acctest.dc1.puppetlabs.net/
                  SSL Key: None
                 SSL Cert: None
              Client UUID: 37084c4a-fdc6-11e1-832b-8800273bd610
          Catalog Updated: September 13, 2012 08:31:25 PM
                  Enabled: Yes
         Signature Policy: verify

- Try installing puppet

        | pkg install puppet
        Creating Plan |
        pkg install: Chain was rooted in an untrusted self-signed certificate.
          The package involved is:pkg://puppetlabs.com/system/management/puppet@3.0.0,5.11-6.192:20120913T212942Z

- We have two choices here, first, to ignore the signature policy for both publisher and image

        | pkg set-publisher --set-property=signature-policy=ignore  puppetlabs.com
        | pkg publisher puppetlabs.com
                Publisher: puppetlabs.com
                    Alias: 
               Origin URI: http://solaris-11-ips-repo.acctest.dc1.puppetlabs.net/
                  SSL Key: None
                 SSL Cert: None
              Client UUID: 140bb5c8-fe62-11e1-af70-8800273bd610
          Catalog Updated: September 14, 2012 05:11:45 PM 
                  Enabled: Yes
         Signature Policy: ignore
        | pkg set-property signature-policy ignore
        | pkg install puppet

- Or trust the self signed certificate from puppetlabs.com (this certificate needs to be published in our web site)

        | pkg set-publisher --approve-ca-cert /root/mycert.pem puppetlabs.com

- Verify that approve cert went well.

        | pkg publisher puppetlabs.com

                Publisher: puppetlabs.com
                    Alias: 
               Origin URI: http://solaris-11-ips-repo.acctest.dc1.puppetlabs.net/
                  SSL Key: None
                 SSL Cert: None
              Client UUID: 37084c4a-fdc6-11e1-832b-8800273bd610
          Catalog Updated: September 13, 2012 08:31:25 PM 
             Approved CAs: 791b5791a81e9c2eb3fb9f84f4f86f8ea6fcd672
                  Enabled: Yes
         Signature Policy: verify

        | pkg install puppet

- Checking about information on the package (See the human readable version string)

        | pkg info -r puppet
                  Name: system/management/puppet
               Summary: Puppet, an automated configuration management tool
           Description: Puppet, an automated configuration management tool
              Category: System/Administration and Configuration
                 State: Not installed
             Publisher: puppetlabs.com
               Version: 3.0.0 (3.0.0-rc6)
         Build Release: 5.11
                Branch: 6.170
        Packaging Date: September 14, 2012 06:11:05 PM 
                  Size: 2.43 MB
                  FMRI: pkg://puppetlabs.com/system/management/puppet@3.0.0,5.11-6.170:20120914T181105Z

- Check license

        | pkg info -r --license puppet
           Puppet - Automating Configuration Management.

           Copyright (C) 2005-2012 Puppet Labs Inc


- Reference

http://docs.oracle.com/cd/E19963-01/html/820-6572/managepkgs.html
