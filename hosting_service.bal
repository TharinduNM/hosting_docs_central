import ballerina/http;
import ballerina/io;
import ballerina/file;
import ballerina/log;
import ballerina/compression;
import ballerina/runtime;
import ballerina/mime;
import ballerina/config;

string unzippedLocation = config:getAsString("UNZIP_LOCATION");
string zipLocation = config:getAsString("ARTIFACT_LOCATION");
string docLocation = config:getAsString("DOC_LOCATION");

@Description {value:"Attributes associated with the service endpoint is defined here."}
endpoint http:Listener apiDocsEP {
    port:9000
};


@Description {value:"By default Ballerina assumes that the service is to be exposed via HTTP/1.1."}
@http:ServiceConfig {
    basePath:"/"
}
service<http:Service> apiDocs bind apiDocsEP {


    @Description {value:"All resources are invoked with arguments of server connector and request"}
    @http:ResourceConfig {
        methods:["GET"],
        path: "/{orgName}/{packageName}/{packageVersion}"
    }
    renderPackageDoc (endpoint conn, http:Request req, string orgName, string packageName, string packageVersion) {

        http:Response res = new;
        string rawPath = req.rawPath;
        io:println(rawPath);

        // create Directories inside the doc location if not already created
        string pkgDocOrgPath = docLocation + orgName;
        createDirectory(pkgDocOrgPath);
        string pkgDocPkgPath = docLocation + orgName + "/" + packageName;
        createDirectory(pkgDocPkgPath);
        string pkgDocVersionPath = docLocation + orgName + "/" + packageName + "/" + packageVersion;
        createDirectory(pkgDocVersionPath);

        //create Directories inside the unzip location if not already created
        string pkgUnzipOrgPath = unzippedLocation + orgName;
        createDirectory(pkgUnzipOrgPath);
        string pkgUnzipPkgPath = unzippedLocation + orgName + "/" + packageName;
        createDirectory(pkgUnzipPkgPath);
        string pkgUnzipVersionPath = unzippedLocation + orgName + "/" + packageName + "/" + packageVersion;
        createDirectory(pkgUnzipVersionPath);

        // check whether docs already generated
        string pkgDocPath = docLocation + orgName + "/" + packageName + "/" + packageVersion + "/api-docs";
        file:Path pkgDocLocation = new (untaint pkgDocPath);
        if (!file:exists(pkgDocLocation)) {
            string unzippedPackageLocation = unzippedLocation + orgName + "/" + packageName + "/" + packageVersion + "/" + packageName;

            //check whether package already unzipped
            file:Path unzippedPkgPath = new (untaint unzippedPackageLocation);
            if (!file:exists(unzippedPkgPath)) {
                file:Path srcPath = new (untaint zipLocation + rawPath + "/" + packageName + ".zip");
                file:Path destPath = new (untaint unzippedLocation + orgName + "/" + packageName + "/" + packageVersion);
                compression:CompressionError err = compression:decompress(srcPath, destPath);
                io:println(err);
            }

            string execMessage = runtime:execBallerina("doc -o " + pkgDocPath, "--sourceroot " + unzippedLocation +
                                                                               orgName + "/" + packageName + "/" +
                                                                               packageVersion + "/ " + packageName);
            io:println(execMessage);
        }

        string path = pkgDocPath + "/index.html";
        file:Path httpPath = new (untaint path);
        res.setFileAsPayload(httpPath, mime:TEXT_HTML);
        if (!rawPath.equalsIgnoreCase("/")) {
            res = getFileAsResponse(pkgDocPath + "/" + packageName + ".html");
        }
        _ = conn -> respond(res);
    }

    @http:ResourceConfig {
        methods:["GET"],
        path: "/*"
    }
    renderDocFiles (endpoint conn, http:Request req) {

        http:Response res = new;
        string rawPath = req.rawPath;
        io:println("renderDocFiles: " + rawPath);

        string pkgDocPath = docLocation + rawPath;

        file:Path httpPath = new (untaint pkgDocPath);
        res.setFileAsPayload(httpPath, mime:TEXT_HTML);
        if (!rawPath.equalsIgnoreCase("/")) {
            res = getFileAsResponse(pkgDocPath);
        }
        _ = conn -> respond(res);
    }
}


function getFileAsResponse (string srcFilePath) returns (http:Response) {

    http:Response res = new;
    file:Path path = new (untaint srcFilePath);
    // Default content type.
    string contentType = mime:APPLICATION_OCTET_STREAM;
    if (!file:exists(path)) {
        res.setStringPayload("Oh no, what you are looking for does not exists.");
        io:println(srcFilePath);
        res.statusCode = 404;
    } else {
        // Finding mime-type by extension
        string fileExtension = getFileExtension(srcFilePath);
        if (!fileExtension.equalsIgnoreCase("")) {
            contentType = getMimeTypeByExtension(fileExtension);
        }

        file:Path requestedFile = new(untaint srcFilePath);

        // Creating response.
        res.setFileAsPayload(requestedFile, contentType);
    }
    return res;
}

public function getFileExtension (string fileName) returns (string) {
    int index = fileName.lastIndexOf(".");
    if (-1 != index) {
        return fileName.subString(index + 1, lengthof fileName);
    } else {
        return "";
    }
}


map MIME_MAP = {
                   "json":mime:APPLICATION_JSON,
                   "xml":mime:TEXT_XML,
                   balo:mime:APPLICATION_OCTET_STREAM,
                   css:"text/css",
                   gif:"image/gif",
                   gif:"image/gif",
                   html:mime:TEXT_HTML,
                   ico:"image/x-icon",
                   jpeg:"image/jpeg",
                   jpg:"image/jpeg",
                   js:"application/javascript",
                   png:"image/png",
                   svg:"image/svg+xml",
                   txt:mime:TEXT_PLAIN,
                   woff2:"font/woff2",
                   zip:"application/zip"
               };

public function getMimeTypeByExtension (string extension) returns (string) {
    any mimeTypeAny = MIME_MAP[extension];
    if (null == mimeTypeAny) {
        return mime:APPLICATION_OCTET_STREAM;
    } else {
        return <string>mimeTypeAny;
    }
}

public function createDirectory (string pkgDocVarPath) {
    file:Path pkgDocVarLocation = new (untaint pkgDocVarPath);
    if (!file:exists(pkgDocVarLocation)) {
        boolean createOrgFlag = check file:createDirectory(pkgDocVarLocation);
    }
}