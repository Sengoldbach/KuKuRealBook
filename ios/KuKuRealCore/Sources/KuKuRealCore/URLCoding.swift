import Foundation

/// Percent-encoding matching JavaScript's `encodeURIComponent` / `decodeURIComponent`
/// exactly (Swift's built-in `.urlQueryAllowed` allows extra characters like
/// `=` and `&` that JS escapes, which would corrupt the `=`-delimited iReal
/// URL fields on round-trip).
public enum URLCoding {
    private static let unreserved: CharacterSet = {
        CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()"
        )
    }()

    public static func encodeURIComponent(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: unreserved) ?? s
    }

    public static func decodeURIComponent(_ s: String) -> String {
        s.removingPercentEncoding ?? s
    }
}
