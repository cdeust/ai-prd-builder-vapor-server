import Foundation

struct ComponentGroupResponse: Codable {
    let name: String
    let components: [ComponentReference]
    let purpose: String?

    struct ComponentReference: Codable {
        let type: String?
        let label: String?
    }

    // Custom decoding to handle both object array and string array formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        purpose = try container.decodeIfPresent(String.self, forKey: .purpose)

        // Try to decode as array of ComponentReference objects first
        if let objectComponents = try? container.decode([ComponentReference].self, forKey: .components) {
            components = objectComponents
        }
        // Fall back to array of strings
        else if let stringComponents = try? container.decode([String].self, forKey: .components) {
            components = stringComponents.map { ComponentReference(type: nil, label: $0) }
        }
        // If both fail, return empty array
        else {
            components = []
        }
    }

    private enum CodingKeys: String, CodingKey {
        case name, components, purpose
    }
}
