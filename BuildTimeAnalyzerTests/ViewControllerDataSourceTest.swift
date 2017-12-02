//
//  ViewControllerDataSourceTest.swift
//  BuildTimeAnalyzerTests
//
//  Created by Dmitrii on 02/12/2017.
//  Copyright © 2017 Cane Media Ltd. All rights reserved.
//

import XCTest
@testable import BuildTimeAnalyzer

class ViewControllerDataSourceTest: XCTestCase {

    var measArray: [CompileMeasure]!

    override func setUp() {
        super.setUp()
        let meas1 = CompileMeasure(rawPath: "FileName1.swift:1:1", time: 10)
        let meas2 = CompileMeasure(rawPath: "FileName2.swift:2:2", time: 2)
        let meas3 = CompileMeasure(rawPath: "FileName3.swift:3:3", time: 8)
        let meas4 = CompileMeasure(rawPath: "FileName3.swift:4:4", time: 0)
        let meas5 = CompileMeasure(rawPath: "FileName1.swift:5:5", time: 2)
        measArray = [meas4!, meas5!, meas2!, meas3!, meas1!]
    }

    func testInit() {
        let dataSource = ViewControllerDataSource()

        XCTAssertFalse(dataSource.aggregateByFile)
        XCTAssertEqual(dataSource.filter, "")
        XCTAssertNotNil(dataSource.sortDescriptors)
        XCTAssertEqual(dataSource.sortDescriptors.count, 0)
        XCTAssertTrue(dataSource.isEmpty())
    }

    func testAggregate() {
        let dataSource = ViewControllerDataSource()
        dataSource.resetSourceData(newSourceData: measArray)
        dataSource.aggregateByFile = true

        XCTAssertEqual(dataSource.count(), 3)
        XCTAssertFalse(dataSource.isEmpty())
    }

    func testFilter_1() {
        let dataSource = ViewControllerDataSource()
        dataSource.resetSourceData(newSourceData: measArray)
        dataSource.filter = "1"

        XCTAssertFalse(dataSource.isEmpty())
        XCTAssertEqual(dataSource.count(), 2)
        XCTAssertEqual(dataSource.measure(index: 0)!.filename, "FileName1.swift")
        XCTAssertEqual(dataSource.measure(index: 1)!.filename, "FileName1.swift")
    }

    func testFilter_2() {
        let dataSource = ViewControllerDataSource()
        dataSource.resetSourceData(newSourceData: measArray)
        dataSource.filter = "2"

        XCTAssertFalse(dataSource.isEmpty())
        XCTAssertEqual(dataSource.count(), 1)
        XCTAssertEqual(dataSource.measure(index: 0)!.filename, "FileName2.swift")
    }

    func testFilter_noMatch() {
        let dataSource = ViewControllerDataSource()
        dataSource.resetSourceData(newSourceData: measArray)
        dataSource.filter = "noMatch"

        XCTAssertTrue(dataSource.isEmpty())
        XCTAssertEqual(dataSource.count(), 0)
    }

    func testSortTimeAscending() {
        let dataSource = ViewControllerDataSource()
        dataSource.resetSourceData(newSourceData: measArray)
        let desc = NSSortDescriptor(key: "time", ascending: true)
        dataSource.sortDescriptors = [desc]

        XCTAssertFalse(dataSource.isEmpty())
        XCTAssertEqual(dataSource.count(), 5)
        XCTAssertEqual(dataSource.measure(index: 0)!.filename, "FileName3.swift")
        XCTAssertEqual(dataSource.measure(index: 1)!.filename, "FileName1.swift")
        XCTAssertEqual(dataSource.measure(index: 2)!.filename, "FileName2.swift")
        XCTAssertEqual(dataSource.measure(index: 3)!.filename, "FileName3.swift")
        XCTAssertEqual(dataSource.measure(index: 4)!.filename, "FileName1.swift")
    }

    func testSortFilenameDescending() {
        let dataSource = ViewControllerDataSource()
        dataSource.resetSourceData(newSourceData: measArray)
        let desc = NSSortDescriptor(key: "filename", ascending: false)
        dataSource.sortDescriptors = [desc]

        XCTAssertFalse(dataSource.isEmpty())
        XCTAssertEqual(dataSource.count(), 5)
        XCTAssertEqual(dataSource.measure(index: 0)!.filename, "FileName3.swift")
        XCTAssertEqual(dataSource.measure(index: 1)!.filename, "FileName3.swift")
        XCTAssertEqual(dataSource.measure(index: 2)!.filename, "FileName2.swift")
        XCTAssertEqual(dataSource.measure(index: 3)!.filename, "FileName1.swift")
        XCTAssertEqual(dataSource.measure(index: 4)!.filename, "FileName1.swift")
    }

    func testSortFilenameAscending_TimeAscending() {
        let dataSource = ViewControllerDataSource()
        dataSource.resetSourceData(newSourceData: measArray)
        let descFilename = NSSortDescriptor(key: "filename", ascending: true)
        let descTime = NSSortDescriptor(key: "time", ascending: true)
        dataSource.sortDescriptors = [descFilename, descTime]

        XCTAssertFalse(dataSource.isEmpty())
        XCTAssertEqual(dataSource.count(), 5)
        XCTAssertEqual(dataSource.measure(index: 0)!.filename, "FileName1.swift")
        XCTAssertEqual(dataSource.measure(index: 0)!.time, 2)
        XCTAssertEqual(dataSource.measure(index: 1)!.filename, "FileName1.swift")
        XCTAssertEqual(dataSource.measure(index: 1)!.time, 10)
        XCTAssertEqual(dataSource.measure(index: 2)!.filename, "FileName2.swift")
        XCTAssertEqual(dataSource.measure(index: 3)!.filename, "FileName3.swift")
        XCTAssertEqual(dataSource.measure(index: 3)!.time, 0)
        XCTAssertEqual(dataSource.measure(index: 4)!.filename, "FileName3.swift")
        XCTAssertEqual(dataSource.measure(index: 4)!.time, 8)
    }

    func testSortTimeAscending_FilenameDescending() {
        let dataSource = ViewControllerDataSource()
        dataSource.resetSourceData(newSourceData: measArray)
        let descTime = NSSortDescriptor(key: "time", ascending: true)
        let descFilename = NSSortDescriptor(key: "filename", ascending: false)
        dataSource.sortDescriptors = [descTime, descFilename]

        XCTAssertFalse(dataSource.isEmpty())
        XCTAssertEqual(dataSource.count(), 5)
        XCTAssertEqual(dataSource.measure(index: 0)!.filename, "FileName3.swift")
        XCTAssertEqual(dataSource.measure(index: 0)!.time, 0)
        XCTAssertEqual(dataSource.measure(index: 1)!.filename, "FileName2.swift")
        XCTAssertEqual(dataSource.measure(index: 1)!.time, 2)
        XCTAssertEqual(dataSource.measure(index: 2)!.filename, "FileName1.swift")
        XCTAssertEqual(dataSource.measure(index: 2)!.time, 2)
        XCTAssertEqual(dataSource.measure(index: 3)!.filename, "FileName3.swift")
        XCTAssertEqual(dataSource.measure(index: 3)!.time, 8)
        XCTAssertEqual(dataSource.measure(index: 4)!.filename, "FileName1.swift")
        XCTAssertEqual(dataSource.measure(index: 4)!.time, 10)
    }

    func testSortTimeAscending_Filter3() {
        let dataSource = ViewControllerDataSource()
        dataSource.resetSourceData(newSourceData: measArray)
        let descTime = NSSortDescriptor(key: "time", ascending: true)
        dataSource.sortDescriptors = [descTime]
        dataSource.filter = "3"

        XCTAssertFalse(dataSource.isEmpty())
        XCTAssertEqual(dataSource.count(), 2)
        XCTAssertEqual(dataSource.measure(index: 0)!.filename, "FileName3.swift")
        XCTAssertEqual(dataSource.measure(index: 0)!.time, 0)
        XCTAssertEqual(dataSource.measure(index: 1)!.filename, "FileName3.swift")
        XCTAssertEqual(dataSource.measure(index: 1)!.time, 8)
    }

    func testFilter3_Aggregate() {
        let dataSource = ViewControllerDataSource()
        dataSource.resetSourceData(newSourceData: measArray)
        dataSource.filter = "3"
        dataSource.aggregateByFile = true

        XCTAssertFalse(dataSource.isEmpty())
        XCTAssertEqual(dataSource.count(), 1)
        XCTAssertEqual(dataSource.measure(index: 0)!.filename, "FileName3.swift")
    }

    func testSortFilenameDescending_FilterCanceled_Aggregate() {
        let dataSource = ViewControllerDataSource()
        dataSource.resetSourceData(newSourceData: measArray)
        let descFilename = NSSortDescriptor(key: "filename", ascending: false)
        dataSource.sortDescriptors = [descFilename]
        dataSource.filter = "2"
        dataSource.aggregateByFile = true
        dataSource.filter = ""

        XCTAssertFalse(dataSource.isEmpty())
        XCTAssertEqual(dataSource.count(), 3)
        XCTAssertEqual(dataSource.measure(index: 0)!.filename, "FileName3.swift")
        XCTAssertEqual(dataSource.measure(index: 1)!.filename, "FileName2.swift")
        XCTAssertEqual(dataSource.measure(index: 2)!.filename, "FileName1.swift")

    }
}
