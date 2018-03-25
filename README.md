# Salesforce S3 Utilities

### Purpose
This is a simple Apex class that interacts with AWS S3

### Deployment
<a href="https://githubsfdeploy.herokuapp.com?owner=cheynepierce&repo=Salesforce-S3-Utility">
  <img alt="Deploy to Salesforce"
       src="https://raw.githubusercontent.com/afawcett/githubsfdeploy/master/src/main/webapp/resources/img/deploy.png">
</a>

### Create a File
1. Create a new organizational level AWS Configuration custom setting, and set your AWS access key and secret key.

2. Create an S3 file by doing the following

```
S3 s3 = new S3('region');
s3.createFile('bucketName', 'path', 'fileName', 'fileContent');
```
