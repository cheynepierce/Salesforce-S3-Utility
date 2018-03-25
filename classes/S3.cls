/**
* Class for interacting with AWS S3 buckets and files. 
* 
* This class provides a method for l
*/
public with sharing class S3 {
	private String ACCESS_KEY;
	private String SECRET_KEY;

	private final String ALGORITHM = 'AWS4-HMAC-SHA256';
	private final String SERVICE = 's3';

	private final String BASE_URL = 'https://s3.amazonaws.com/';
	private final String EXPIRES = '86400';

	private final String XML_NAMESPACE = 'http://s3.amazonaws.com/doc/2006-03-01/';

	private Map<String, String> parametersMap;

	private String region;
	private String bucketName;
	private String fileName;
	private String body;
	private String d;
	private String timestamp;
	private String folderName;
	private String resource;
	private String scope;
	private String parameterString;
	private String canonicalRequest;

	public S3(String region) {
		this.region = region;

		this.d = this.getDate();
		this.timestamp = this.getTimestamp();

		AWS_Configuration__c awsConfig = AWS_Configuration__c.getOrgDefaults();
        this.ACCESS_KEY = awsConfig.Access_Key__c;
        this.SECRET_KEY = awsConfig.Secret_Key__c;
	}

	/**
	* Get a list of files in the specified folder of the specified bucket
	*/
	public Map<String, String> getFileList(String bucketName, String folderName) {
		this.bucketName = bucketName;
		this.resource = folderName;
		this.body = '';

		HttpResponse resp = this.getFolder();
		return this.parseFilesXml(resp);
	} 

	/**
	* Make an HTTP request to S3 to get the list of files as XML
	*/
	private HttpResponse getFolder() {
		Http http = new Http();
		HttpRequest req = this.getFolderRequest();

		HttpResponse resp = http.send(req);
		return resp;
	}

	/**
	* Generate the HTTP request to get the list of files in the specified folder.
	*/
	private HttpRequest getFolderRequest() {
		this.parameterString = 'prefix=' + this.resource;
		String url = this.BASE_URL + '/' + this.bucketName + '/' + 'test.txt' + '?' + this.parameterString;

		HttpRequest req = new HttpRequest();

		req.setEndpoint(url);
		req.setMethod('GET');
		req.setHeader('X-Amz-Content-SHA256', this.getXAmzContent());
		req.setHeader('X-Amz-Date', this.timestamp);
		req.setHeader('Authorization', this.getAuthHeader());

		return req;
	}

	/**
	* Parse the files XML and return a list of file names in the folder.
	*/
	private Map<String, String> parseFilesXml(HttpResponse resp) {
		system.debug(resp.getBody());
		Dom.Document doc = resp.getBodyDocument();
		Dom.XMLNode listBucketResult = doc.getRootElement();

		Map<String, String> files = new Map<String, String>();
		for (Dom.XMLNode node : listBucketResult.getChildElements()) {
			if (node.getName() == 'Contents') {
				if (node.getChildElement('Size', this.XML_NAMESPACE).getText() != '0') {
					String fileName = node.getChildElement('Key', this.XML_NAMESPACE).getText();
					String fileExtension = fileName.substringAfter('.');
					files.put(fileExtension, this.getFileUrl(fileName));
				}
			}
		}
		return files;
	}

	public void createFile(String bucketName, String folderName, String fileName, String body) {
		this.bucketName = bucketName;
		this.folderName = folderName;
		this.fileName = fileName;
		this.body = body;

		HttpResponse resp = this.putFile();
		system.debug(resp);
		system.debug(resp.getBody());
	}

	private HttpResponse putFile() {
		Http http = new Http();
		HttpRequest req = this.getPutRequest();

		HttpResponse resp = http.send(req);
		return resp;
	}

	private HttpRequest getPutRequest() {
		String url = 'https://' + this.bucketName + '.s3.amazonaws.com/' + this.folderName + '/' + this.fileName;

		HttpRequest req = new HttpRequest();

		req.setEndpoint(url);
		req.setMethod('PUT');
		req.setHeader('X-Amz-Content-SHA256', this.getXAmzContent());
		req.setHeader('X-Amz-Date', this.timestamp);
		req.setHeader('Authorization', this.getPutAuthHeader());
		req.setHeader('Content-Type', 'text/plain');
		req.setHeader('Content-Length', String.valueOf(this.body.length()));

		system.debug(req.getHeader('X-Amz-Content-SHA256'));

		req.setBody(body);

		return req;
	}

	private String getXAmzContent() {
		return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(this.body)));
	}

	/**
	* Generate the authorization header for the list bucket operation.
	*/
	private String getAuthHeader() {
		String authHeader = this.ALGORITHM + ' ';
		this.scope = this.getScope();
		this.canonicalRequest = this.getFolderCanonicalRequest();

		authHeader += 'Credential=' + this.ACCESS_KEY + '/' + this.scope + ', ';
		authHeader += 'SignedHeaders=host;x-amz-content-sha256;x-amz-date, ';
		authHeader += 'Signature=' + this.getSignature();

		return authHeader;
	}

	/**
	* Generate the authorization header for the PUT object operation.
	*/
	private String getPutAuthHeader() {
		String authHeader = this.ALGORITHM + ' ';
		this.scope = this.getScope();
		this.canonicalRequest = this.getPutCanonicalRequest();

		authHeader += 'Credential=' + this.ACCESS_KEY + '/' + this.scope + ', ';
		authHeader += 'SignedHeaders=date;host;x-amz-content-sha256;x-amz-date, ';
		authHeader += 'Signature=' + this.getSignature();

		system.debug('authHeader ==> ' + '\n' + authHeader);
		return authHeader;
	}

	/**
	* Get the URL with query string authorization for a specific file.
	*/
	public String getFileUrl(String resource) {
		this.resource = resource;

		String url = this.BASE_URL + '/' + this.bucketName + '/' + this.resource; 

		this.folderName = this.resource.split('/')[0];
		this.fileName = this.resource.split('/')[1];

		this.setParameters();
		this.parameterString = this.getParameterString() + '&X-Amz-SignedHeaders=host';
		this.canonicalRequest = this.getFileCanonicalRequest();

		String signature = this.getSignature();

		return url + '?' + parameterString + '&X-Amz-Signature=' + signature;
	}

	/**
	* Set up a map of parameters for the file URL.
	*/
	private void setParameters() {
		this.parametersMap = new Map<String, String>();
		this.parametersMap.put('X-Amz-Algorithm', this.ALGORITHM);
		this.scope = this.getScope();
		this.parametersMap.put('X-Amz-Credential', this.ACCESS_KEY + '/' + this.scope);
		this.parametersMap.put('X-Amz-Date', this.timestamp);
		this.parametersMap.put('X-Amz-Expires', this.EXPIRES);
	}

	/**
	* Construct the AWS scope parameter.
	*/
	private String getScope() {
		return this.d + '/' + this.region + '/' + this.SERVICE + '/aws4_request';
	}

	/**
	* Converts the parameters map to a query string
	*/
	private String getParameterString() {
		String parameters = '';
		for (String key : this.parametersMap.keySet()) {
			parameters += key + '=' + EncodingUtil.urlEncode(this.parametersMap.get(key), 'UTF-8') + '&';
		}
		parameters = parameters.left(parameters.length()-1);
		return parameters;
	}

	/**
	* Returns the current date in string format (YYYYMMDD)
	*/
	private String getDate() {
		return String.valueOf(Datetime.now().yearGmt()) + 
				this.getString(Datetime.now().monthGmt()) + 
				this.getString(Datetime.now().dayGmt());
	}

	/**
	* Returns the current timestamp in ISO format (YYYYMMDDTHHMMSSZ)
	*/
	private String getTimestamp() {
		Datetime dt = Datetime.now();
		return this.getString(dt.year()) + 
				this.getString(dt.monthGmt()) + 
				this.getString(dt.dayGmt()) + 'T' + 
				this.getString(dt.hourGmt()) + 
				this.getString(dt.minuteGmt()) + 
				this.getString(dt.secondGmt()) + 
				'Z';
	}

	/**
	* Convert a date/time component to string format (prependig a '0' if necessary).
	*/
	private String getString(Integer comp) {
		String s = String.valueOf(comp);
		if (s.length() == 1) {
			return '0'+s;
		}
		return s;
	}

	/**
	* Generate the request signature
	*/
	private String getSignature() {
		return EncodingUtil.convertToHex(Crypto.generateMac('hmacSHA256', this.getStringToSign(), this.getSigningKey()));
	}

	/**
	* Generate the string to sign for S3 authorization.
	*/
	private Blob getStringToSign() {
		String stringToSign = this.ALGORITHM + '\n' + 
				this.timestamp + '\n' + 
				this.scope + '\n' + 
				EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(this.canonicalRequest)));
		system.debug('string to sign ==> \n' + stringToSign);
		return Blob.valueOf(stringToSign);
	}

	/**
	* Generate the canonical request needed for the list bucket operation.
	*/
	private String getFolderCanonicalRequest() {
		String canonicalRequest = 'GET\n' + 
				'//' + this.bucketName + '\n' + 
				this.parameterString + '\n' + 
				'host:s3.amazonaws.com' + '\n' + 
				'x-amz-content-sha256:' + EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(''))) + '\n' + 
				'x-amz-date:' + this.timestamp + '\n\n' + 
				'host;x-amz-content-sha256;x-amz-date\n' + 
				EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf('')));
		return canonicalRequest;
	}

	/**
	* Generate the canonical request needed for query string authorization.
	*/ 
	private String getFileCanonicalRequest() {
		String req = 'GET\n' + 
				'//' + this.bucketName + '/' + this.folderName + '/' + this.urlEncode(this.fileName) + '\n' + 
				this.parameterString + '\n' + 
				'host:s3.amazonaws.com' + '\n\n' + 
				'host\n' + 
				'UNSIGNED-PAYLOAD';
		system.debug('canonical request ==> \n' + req);
		return req;
	}

	/**
	* Generate the canonical request needed for the PUT operation.
	*/ 
	private String getPutCanonicalRequest() {
		String req = 'PUT\n' + 
				'/' + this.folderName + '/' + this.urlEncode(this.fileName) + '\n' + 
				'' + '\n' + 
				'date:' + '\n' + 
				'host:' + this.bucketName + '.s3.amazonaws.com' + '\n' + 
				'x-amz-content-sha256:' + this.getXAmzContent() + '\n' + 
				'x-amz-date:' + this.timestamp + '\n\n' + 
				'date;host;x-amz-content-sha256;x-amz-date' + '\n' + 
				this.getXAmzContent();
		system.debug('canonical request ==> \n' + req);
		return req;
	}

	private String urlEncode(String url) {
		return EncodingUtil.urlEncode(url, 'UTF-8').replace('+', '%20');
	}

	/**
	* Generate the AWS signing key.
	*/
	private Blob getSigningKey() {
		Blob kDate = Crypto.generateMac('hmacSHA256', Blob.valueOf(this.d), Blob.valueOf('AWS4' +this.SECRET_KEY));
		Blob kRegion = Crypto.generateMac('hmacSHA256', Blob.valueOf(this.region), kDate);
		Blob kService = Crypto.generateMac('hmacSHA256', Blob.valueOf(this.SERVICE), kRegion);
		Blob kSigning = Crypto.generateMac('hmacSHA256', Blob.valueOf('aws4_request'), kService);
		return kSigning;
	}
}