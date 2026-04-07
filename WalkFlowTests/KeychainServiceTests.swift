import XCTest
@testable import WalkFlow

final class KeychainServiceTests: XCTestCase {
    private let testKey = "com.walkflow.test.token"

    override func tearDown() {
        super.tearDown()
        KeychainService.delete(key: testKey)
    }

    func testSaveAndLoad() {
        let token = "test-gateway-token-12345"
        let saved = KeychainService.save(key: testKey, value: token)
        XCTAssertTrue(saved)

        let loaded = KeychainService.load(key: testKey)
        XCTAssertEqual(loaded, token)
    }

    func testLoadReturnsNilWhenNotSaved() {
        let loaded = KeychainService.load(key: testKey)
        XCTAssertNil(loaded)
    }

    func testDeleteRemovesToken() {
        KeychainService.save(key: testKey, value: "to-be-deleted")
        KeychainService.delete(key: testKey)
        let loaded = KeychainService.load(key: testKey)
        XCTAssertNil(loaded)
    }

    func testOverwriteExistingValue() {
        KeychainService.save(key: testKey, value: "old-token")
        let saved = KeychainService.save(key: testKey, value: "new-token")
        XCTAssertTrue(saved)

        let loaded = KeychainService.load(key: testKey)
        XCTAssertEqual(loaded, "new-token")
    }

    func testGatewayTokenConvenience() {
        let token = "gateway-token-abc"
        KeychainService.saveGatewayToken(token)
        XCTAssertEqual(KeychainService.loadGatewayToken(), token)

        KeychainService.deleteGatewayToken()
        XCTAssertNil(KeychainService.loadGatewayToken())
    }
}
