import MissingMacros
import Foundation

let a = 17
let b = 25

let (result, code) = #stringify(a + b)

print("The value \(result) was produced by the code \"\(code)\"")

let url = #url("https://developer.apple.com")
print("Statically validated URL: \(url)")
