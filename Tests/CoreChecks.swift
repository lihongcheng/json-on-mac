import Foundation

@main
enum CoreChecks {
    static func main() throws {
        try testParseBuildsTreeStatisticsAndTable()
        try testFormatting()
        try testEmbeddedJSONPresentationPreservesOriginalValues()
        try testQuery()
        try testDiff()
        testCSV()
        testInvalidJSON()
        print("Core checks passed: 7/7")
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: String
    ) {
        guard condition() else {
            fatalError("Check failed: \(message)")
        }
    }

    private static func testParseBuildsTreeStatisticsAndTable() throws {
        let parsed = try JSONEngine.parse(
            """
            [
              {"id": 1, "name": "Alpha", "active": true},
              {"id": 2, "name": "Beta", "active": false}
            ]
            """
        )

        expect(parsed.rootNode.kind == .array, "root kind")
        expect(parsed.rootNode.children.count == 2, "tree children")
        expect(parsed.statistics.arrays == 1, "array count")
        expect(parsed.statistics.objects == 2, "object count")
        expect(parsed.statistics.keys == 6, "key count")
        expect(parsed.statistics.strings == 2, "string count")
        expect(parsed.statistics.numbers == 2, "number count")
        expect(parsed.statistics.booleans == 2, "boolean count")
        expect(parsed.table?.columns == ["active", "id", "name"], "table columns")
        expect(parsed.table?.rows.count == 2, "table rows")
    }

    private static func testFormatting() throws {
        let parsed = try JSONEngine.parse(#"{"a":{"b":1}}"#, indent: 4)

        expect(parsed.formatted.contains("\n    \"a\""), "first indentation level")
        expect(parsed.formatted.contains("\n        \"b\""), "second indentation level")
        expect(parsed.minified == #"{"a":{"b":1}}"#, "minified output")

        let fragment = try JSONEngine.parse(#""standalone""#)
        expect(fragment.minified == #""standalone""#, "top-level JSON fragment")
    }

    private static func testEmbeddedJSONPresentationPreservesOriginalValues() throws {
        let userExtra = try JSONEngine.serialize(
            [
                "RPC_PERSIST_HOST": "voice.ap-southeast-1.bytepluses.com",
                "RPC_PERSIST_speech_session_id": "39dadfde-f399-4dfa-b801-bec4e8d7a650"
            ],
            pretty: false
        )
        let queryValue = try JSONEngine.serialize(
            [
                "audio": ["bits": 16, "format": "pcm"] as [String: Any],
                "Base": [
                    "Caller": "data.speech.gateway",
                    "extra": [
                        "cluster": "tob",
                        "user_extra": userExtra
                    ]
                ] as [String: Any]
            ],
            pretty: false
        )
        let source = try JSONEngine.serialize(
            [
                "duration": 13_600,
                "query": queryValue,
                "invalid": #"{"broken":}"#,
                "scalar": "123",
                "plain": "[not json]"
            ] as [String: Any],
            pretty: false
        )

        let parsed = try JSONEngine.parse(source, indent: 4)
        expect(parsed.embeddedJSONCount == 2, "embedded JSON count")
        expect(parsed.presentationFormatted.contains("\n    \"query\" : {"), "query preview indentation")
        expect(parsed.presentationFormatted.contains("\n        \"Base\" : {"), "embedded object indentation")
        expect(
            parsed.presentationFormatted.contains("\n                \"user_extra\" : {"),
            "nested embedded string indentation"
        )
        expect(
            parsed.presentationFormatted.contains("\n                    \"RPC_PERSIST_HOST\""),
            "deep preview indentation"
        )

        let output = try JSONSerialization.jsonObject(with: Data(parsed.formatted.utf8)) as? [String: Any]
        expect(output?["query"] as? String == queryValue, "source formatting preserves query string")
        expect(output?["invalid"] as? String == #"{"broken":}"#, "invalid JSON string unchanged")
        expect(output?["scalar"] as? String == "123", "scalar-like string unchanged")
        expect(output?["plain"] as? String == "[not json]", "plain bracket string unchanged")

        let queryNode = parsed.rootNode.children.first { $0.name == "query" }
        expect(queryNode?.kind == .string, "query remains a string node")
        expect(queryNode?.embeddedJSONKind == .object, "query exposes object presentation")
        expect(queryNode?.copyValue == queryValue, "query tree copy preserves original")

        let userExtraNode = queryNode?
            .children.first { $0.name == "Base" }?
            .children.first { $0.name == "extra" }?
            .children.first { $0.name == "user_extra" }
        expect(userExtraNode?.kind == .string, "user_extra remains a string node")
        expect(userExtraNode?.embeddedJSONKind == .object, "user_extra expands recursively")
        expect(userExtraNode?.copyValue == userExtra, "user_extra copy preserves original")

        let queryResult = try JSONEngine.query("$.query", in: parsed.value).first
        expect(queryResult?.kind == .string, "query result keeps source type")
        expect(queryResult?.displayKind == .object, "query result renders as object")
        expect(queryResult?.isEmbeddedJSON == true, "query result marks formatted preview")
        expect(queryResult?.displayValue.contains("\n") == true, "query result is pretty printed")
        expect(queryResult?.displayValue.contains("\"user_extra\" : {") == true, "nested JSON is expanded")
        expect(queryResult?.copyValue == queryValue, "query result copies original string")

        let nestedResult = try JSONEngine.query(
            "$.query.Base.extra.user_extra.RPC_PERSIST_HOST",
            in: parsed.value
        )
        expect(nestedResult.first?.copyValue == "voice.ap-southeast-1.bytepluses.com", "nested path query")
    }

    private static func testQuery() throws {
        let parsed = try JSONEngine.parse(
            """
            {
              "users": [
                {"id": 1, "profile": {"name": "A"}},
                {"id": 2, "profile": {"name": "B"}}
              ]
            }
            """
        )

        let wildcard = try JSONEngine.query("$.users[*].id", in: parsed.value)
        expect(wildcard.map(\.displayValue) == ["1", "2"], "wildcard query")

        let bracket = try JSONEngine.query("$['users'][1]['profile']['name']", in: parsed.value)
        expect(bracket.first?.displayValue == "\"B\"", "bracket query")

        let recursive = try JSONEngine.query("$..name", in: parsed.value)
        expect(recursive.count == 2, "recursive query count")
        expect(
            recursive.map(\.path) == ["$.users[0].profile.name", "$.users[1].profile.name"],
            "recursive query paths"
        )
    }

    private static func testDiff() throws {
        let left = try JSONEngine.parse(#"{"name":"old","obsolete":true,"items":[1,2]}"#)
        let right = try JSONEngine.parse(#"{"name":"new","added":3,"items":[1,4,5]}"#)
        let entries = JSONEngine.diff(left.value, right.value)

        expect(entries.contains { $0.path == "$.added" && $0.kind == .added }, "added field")
        expect(entries.contains { $0.path == "$.obsolete" && $0.kind == .removed }, "removed field")
        expect(entries.contains { $0.path == "$.name" && $0.kind == .modified }, "modified field")
        expect(entries.contains { $0.path == "$.items[1]" && $0.kind == .modified }, "modified array item")
        expect(entries.contains { $0.path == "$.items[2]" && $0.kind == .added }, "added array item")
    }

    private static func testCSV() {
        let table = JSONTable(
            columns: ["name", "note"],
            rows: [["name": "A, B", "note": #"say "hi""#]]
        )
        let expected = "\"name\",\"note\"\n\"A, B\",\"say \"\"hi\"\"\""
        expect(JSONEngine.csv(from: table) == expected, "CSV escaping")
    }

    private static func testInvalidJSON() {
        do {
            _ = try JSONEngine.parse(#"{"a":}"#)
            fatalError("Check failed: invalid JSON accepted")
        } catch JSONEngineError.invalid {
            return
        } catch {
            fatalError("Check failed: unexpected invalid JSON error \(error)")
        }
    }
}
