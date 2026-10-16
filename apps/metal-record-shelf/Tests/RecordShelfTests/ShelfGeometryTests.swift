import XCTest
@testable import RecordShelf

final class ShelfGeometryTests: XCTestCase {
    func testVisualCenterMatchesSystemPhotoWidgetDespiteTransparentPadding() {
        let area = CGRect(x: 0, y: 0, width: 1470, height: 920)
        let old = CGRect(x: 16, y: 18, width: 400, height: 476)
        let aligned = ShelfGeometry.alignedFrame(in: area, previous: old)
        let cabinet = ShelfGeometry.visibleCabinet(in: aligned)
        let photo = CGRect(x: 16, y: 500, width: 344, height: 164)
        XCTAssertEqual(cabinet.minX, photo.minX, accuracy: 0.01)
        XCTAssertEqual(cabinet.maxX, photo.maxX, accuracy: 0.01)
        XCTAssertEqual(cabinet.midX, photo.midX, accuracy: 0.01)
        XCTAssertEqual(aligned.maxY, old.maxY, accuracy: 0.01)
        XCTAssertTrue(area.contains(cabinet))
        XCTAssertLessThan(aligned.minX, area.minX)
    }
    func testAlignmentUsesChosenDisplayOriginAndKeepsVisibleCabinetOnscreen() {
        let area = CGRect(x: -1920, y: 100, width: 1920, height: 1080)
        for y: CGFloat in [-400, 180, 2500] {
            let aligned = ShelfGeometry.alignedFrame(in: area, previous: CGRect(x: -1800, y: y, width: 400, height: 476))
            let cabinet = ShelfGeometry.visibleCabinet(in: aligned)
            XCTAssertEqual(cabinet.minX, area.minX + 16, accuracy: 0.01)
            XCTAssertTrue(area.contains(cabinet))
        }
    }
}
