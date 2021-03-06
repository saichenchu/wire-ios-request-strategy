// 
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
// 


import Foundation

public final class AssetRequestFactory : NSObject {
    
    let jsonContentType = "application/json"
    let octetStreamContentType = "application/octet-stream"
    
    public enum Retention : String {
        case persistent = "persistent"
        case eternal = "eternal"
        case volatile = "volatile"
    }

    public func backgroundUpstreamRequestForAsset(message: ZMAssetClientMessage, withData data: Data, shareable: Bool = true, retention: Retention = .persistent) -> ZMTransportRequest? {
        let path = "/assets/v3"
        guard let uploadURL = uploadURL(for: message, in: message.managedObjectContext!, shareable: shareable, retention: retention, data: data) else { return nil }
        let request = ZMTransportRequest.uploadRequest(withFileURL: uploadURL, path: path, contentType: "multipart/mixed; boundary=frontier")
        request.addContentDebugInformation("Uploading full asset to /assets/v3")
        return request
    }

    public func upstreamRequestForAsset(withData data: Data, shareable: Bool = true, retention : Retention = .persistent) -> ZMTransportRequest? {
        let path = "/assets/v3"
        guard let multipartData = try? dataForMultipartAssetUploadRequest(data, shareable: shareable, retention: retention) else { return nil }
        let request = ZMTransportRequest(path: path, method: .methodPOST, binaryData: multipartData, type: "multipart/mixed; boundary=frontier", contentDisposition: nil)
        return request
    }

    func dataForMultipartAssetUploadRequest(_ data: Data, shareable: Bool, retention : Retention) throws -> Data {
        let fileDataHeader = ["Content-MD5": (data as NSData).zmMD5Digest().base64String()]
        let metaData = try JSONSerialization.data(withJSONObject: ["public" : shareable, "retention" : retention.rawValue ], options: [])

        return NSData.multipartData(withItems: [
            ZMMultipartBodyItem(data: metaData, contentType: jsonContentType, headers: nil),
            ZMMultipartBodyItem(data: data, contentType: octetStreamContentType, headers: fileDataHeader),
            ], boundary: "frontier")
    }

    private func uploadURL(for message: ZMAssetClientMessage, in moc: NSManagedObjectContext, shareable: Bool, retention: Retention, data: Data) -> URL? {
        guard let multipartData = try? dataForMultipartAssetUploadRequest(data, shareable: shareable, retention: retention) else { return nil }
        return moc.zm_fileAssetCache.storeRequestData(message.nonce, data: multipartData)
    }
    
}
