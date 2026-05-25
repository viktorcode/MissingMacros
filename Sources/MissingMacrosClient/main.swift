import MissingMacros
import Foundation

let url = #url("https://developer.apple.com")
print("Statically validated URL: \(url)")

struct MyStruct {
    @AddAsync
    func doThrowing(a: Int, for b: String, _ value: Double, completionBlock: @escaping (Result<String, Error>) -> Void) {
        completionBlock(.success("a: \(a), b: \(b), value: \(value)"))
    }

    @AddAsync
    func doResult(a: Int, for b: String, _ value: Double, completionBlock: @escaping (Bool) -> Void) {
        completionBlock(true)
    }
}

let myStruct = MyStruct()
let resultOne = (try? await myStruct.doThrowing(a: 5, for: "Test", 20)) ?? "It failed"
print(resultOne)
let resultTwo = await myStruct.doResult(a: 10, for: "value", 40)
print(resultTwo)
