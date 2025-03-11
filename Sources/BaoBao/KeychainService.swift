import Foundation
import Security
import os.log

class KeychainService {
    static let shared = KeychainService()
    private let logger = Logger(subsystem: "com.example.baobao", category: "KeychainService")
    
    private let serviceName = "com.example.baobao"
    
    private init() {}
    
    func setValue(_ value: String, for key: String) {
        // 准备查询
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: value.data(using: .utf8)!
        ]
        
        // 尝试删除已存在的项
        SecItemDelete(query as CFDictionary)
        
        // 添加新项
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            logger.info("✅ 密钥已保存到钥匙串：\(key)")
        } else {
            logger.error("❌ 保存密钥失败：\(status)")
        }
    }
    
    func getValue(for key: String) -> String? {
        // 准备查询
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            logger.error("❌ 读取密钥失败：\(status)")
            return nil
        }
        
        logger.info("✅ 成功读取密钥：\(key)")
        return value
    }
    
    func removeValue(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess {
            logger.info("✅ 密钥已从钥匙串删除：\(key)")
        } else {
            logger.error("❌ 删除密钥失败：\(status)")
        }
    }
} 