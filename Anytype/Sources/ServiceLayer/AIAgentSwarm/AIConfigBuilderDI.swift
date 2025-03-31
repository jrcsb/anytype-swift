import Foundation
import Factory

extension Container {
    var aiConfigBuilder: Factory<any AIConfigBuilderProtocol> {
        self { AIConfigBuilder() }.shared
    }
}
