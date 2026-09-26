import XCTest
@testable import PitchLab

final class MusicXMLParserTests: XCTestCase {
    func testReadsFirstPartMelodyAndSkipsRestsAndChords() throws {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <score-partwise version="4.0"><part id="P1"><measure number="1">
          <note><pitch><step>C</step><octave>4</octave></pitch></note>
          <note><pitch><step>D</step><alter>1</alter><octave>4</octave></pitch></note>
          <note><rest/></note>
          <note><chord/><pitch><step>G</step><octave>4</octave></pitch></note>
          <note><pitch><step>E</step><alter>-1</alter><octave>4</octave></pitch></note>
        </measure></part><part id="P2"><measure number="1">
          <note><pitch><step>A</step><octave>4</octave></pitch></note>
        </measure></part></score-partwise>
        """
        XCTAssertEqual(try MusicXMLParser.parse(data: Data(xml.utf8)), [60, 63, 63])
    }

    func testRejectsMalformedXML() {
        XCTAssertThrowsError(try MusicXMLParser.parse(data: Data("<score-partwise><part>".utf8)))
    }

    func testUsesOnlyFirstVoiceWithinFirstPart() throws {
        let xml = """
        <score-partwise><part id="P1"><measure number="1">
          <note><pitch><step>C</step><octave>4</octave></pitch><voice>1</voice></note>
          <backup><duration>1</duration></backup>
          <note><pitch><step>E</step><octave>4</octave></pitch><voice>2</voice></note>
        </measure></part></score-partwise>
        """
        XCTAssertEqual(try MusicXMLParser.parse(data: Data(xml.utf8)), [60])
    }
}
