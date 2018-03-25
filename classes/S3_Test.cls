@isTest
private class S3_Test {
	public static final String region = 'us-east-1';
	public static final String bucketName = 'test';
	public static final String folderName = 'test';

	//static testMethod void testGetFileList() {
	//	Test.setMock(HttpCalloutMock.class, getFileListRequestMock());

	//	S3 s3 = new S3(region);
	//	Map<String, String> filesList = s3.getFileList(bucketName, folderName);

	//}

	//static testMethod void testGetFileUrl() {
	//	Test.setMock(HttpCalloutMock.class, getFileUrlRequestMock());

	//	S3 s3 = new S3(region);
	//	String fileUrl = s3.getFileUrl('folder/file.txt');
	//}

	static testMethod void testCreateFile() {
		Test.setMock(HttpCalloutMock.class, getCreateFileRequestMock());

		S3 s3 = new S3(region);
		s3.createFile(bucketName, folderName, 'test.txt', 'test content');
	}

	static SingleRequestMock getFileListRequestMock() {
		Map<String, String> responseHeaders = new Map<String, String>{
			'Content-Type' => 'application/x-www-form-urlencoded'
		};

		SingleRequestMock mock = new SingleRequestMock(
			200, 'Success', '{"content": "Hello, world"}', responseHeaders
		);

		return mock;
	}

	static SingleRequestMock getFileUrlRequestMock() {
		Map<String, String> responseHeaders = new Map<String, String>{
			'Content-Type' => 'application/x-www-form-urlencoded'
		};

		SingleRequestMock mock = new SingleRequestMock(
			200, 'Success', '{"content": "Hello, world"}', responseHeaders
		);

		return mock;
	}

	static SingleRequestMock getCreateFileRequestMock() {
		Map<String, String> responseHeaders = new Map<String, String>();

		SingleRequestMock mock = new SingleRequestMock(
			200, 'Success', '', responseHeaders
		);

		return mock;
	}
}