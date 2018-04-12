import ballerina/http;
import ballerina/io;
import ballerina/file;
import ballerina/log;
import ballerina/compression;
import ballerina/runtime;
import ballerina/mime;

@Description {value:"Attributes associated with the service endpoint is defined here."}
endpoint http:Listener apiDocsEP {
    port:9090
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
    renderDocs (endpoint conn, http:Request req, string orgName, string packageName, string packageVersion) {

        http:Response res = new;
        string rawPath = req.rawPath;
        file:Path pkgPath = new (untaint
                             "/home/tharindu/Documents/ballerina_files/hosting_docs_central/testing/unzipped/oauth2");
        string unzippedLocation = "/home/tharindu/Documents/ballerina_files/hosting_docs_central/testing/unzipped/";
        if (!file:exists(pkgPath)) {
            file:Path srcPath = new (untaint
                           "/home/tharindu/Documents/ballerina_files/hosting_docs_central/testing/zip/oauth2.zip");
            file:Path destPath = new (untaint unzippedLocation);
            compression:CompressionError err = compression:decompress(srcPath, destPath);
            io:println(err);
        }

        file:Path pkgUnzippedFile = new (untaint unzippedLocation + "api-docs");
        if (!file:exists(pkgUnzippedFile)) {
            string execMessage = runtime:execBallerina("doc -o " + unzippedLocation + "api-docs",
                                                       "--sourceroot
                                                       /home/tharindu/Documents/ballerina_files/hosting_docs_central/testing/unzipped/ oauth2");
            io:println(execMessage);
        }

        string path = unzippedLocation + "api-docs/" + "index.html";
        file:Path httpPath = new (untaint path);
        res.setFileAsPayload(httpPath, mime:TEXT_HTML);
        if (!rawPath.equalsIgnoreCase("/")) {
            res = getFileAsResponse(unzippedLocation + "api-docs" + rawPath);
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