import Foundation
import UIKit

extension UIImage {
    func cropped(boundingBox: CGRect) -> UIImage? {
        guard let cgImage = self.cgImage?.cropping(to: boundingBox) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    func crop(rect : CGRect) -> UIImage? {
        var imageRect = rect
        if (self.scale > 1.0) {
            imageRect = CGRect(x: rect.origin.x * self.scale,
                               y: rect.origin.y * self.scale,
                               width: rect.size.width * self.scale,
                               height: rect.size.height * self.scale);
        }
        guard let cgImage = self.cgImage else {
            return nil
        }
        guard let imageRef = cgImage.cropping(to: imageRect) else {
            return nil
        }
        let result = UIImage(cgImage: imageRef, scale: self.scale, orientation: self.imageOrientation)
        return result;
    }
}
