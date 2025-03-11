import Foundation
import os.log

// MARK: - API错误类型
enum APIError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed(Error)
    case serverError(Int, String)
    case networkUnavailable
    case rateLimited
    case timeout
    case unknown
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "无效的URL地址"
        case .requestFailed(let error):
            return "请求失败: \(error.localizedDescription)"
        case .invalidResponse:
            return "无效的服务器响应"
        case .decodingFailed(let error):
            return "数据解析失败: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "服务器错误 (\(code)): \(message)"
        case .networkUnavailable:
            return "网络连接不可用"
        case .rateLimited:
            return "请求频率超限，请稍后再试"
        case .timeout:
            return "请求超时"
        case .unknown:
            return "未知错误"
        }
    }
}

// MARK: - API服务
class APIService {
    // 单例模式
    static let shared = APIService()
    
    // 创建专用的日志记录器
    private let logger = Logger(subsystem: "com.baobao.app", category: "api-service")
    
    // 基础URL
    private let baseURL = "https://api.deepseek.com/v1"
    
    // API密钥
    private var apiKey: String? {
        // 从环境变量或配置文件中获取API密钥
        // 这里暂时使用一个占位符
        return ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"]
    }
    
    // 会话配置
    private let session: URLSession
    
    // 私有初始化方法
    private init() {
        // 配置会话
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        configuration.waitsForConnectivity = true
        
        // 添加默认的请求头
        configuration.httpAdditionalHeaders = [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        
        self.session = URLSession(configuration: configuration)
        
        logger.info("API服务初始化完成")
    }
    
    // MARK: - 通用请求方法
    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil,
        completion: @escaping (Result<T, APIError>) -> Void
    ) {
        // 构建完整URL
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            logger.error("❌ 无效的URL: \(self.baseURL)/\(endpoint)")
            completion(.failure(.invalidURL))
            return
        }
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // 添加API密钥到请求头
        if let apiKey = apiKey {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("strict", forHTTPHeaderField: "X-Safety-Level")
        }
        
        // 添加自定义请求头
        headers?.forEach { key, value in
            request.addValue(value, forHTTPHeaderField: key)
        }
        
        // 添加请求参数
        if let parameters = parameters {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: parameters, options: [])
                request.httpBody = jsonData
            } catch {
                logger.error("❌ 参数序列化失败: \(error.localizedDescription)")
                completion(.failure(.requestFailed(error)))
                return
            }
        }
        
        // 记录请求信息
        logger.info("🚀 发送请求: \(method) \(url.absoluteString)")
        if let parameters = parameters {
            logger.debug("📦 请求参数: \(parameters)")
        }
        
        // 发送请求
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // 处理错误
            if let error = error {
                self.logger.error("❌ 请求失败: \(error.localizedDescription)")
                
                // 根据错误类型进行分类
                let apiError: APIError
                let nsError = error as NSError
                
                if nsError.domain == NSURLErrorDomain {
                    switch nsError.code {
                    case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                        apiError = .networkUnavailable
                    case NSURLErrorTimedOut:
                        apiError = .timeout
                    default:
                        apiError = .requestFailed(error)
                    }
                } else {
                    apiError = .requestFailed(error)
                }
                
                completion(.failure(apiError))
                return
            }
            
            // 检查响应
            guard let httpResponse = response as? HTTPURLResponse else {
                self.logger.error("❌ 无效的响应")
                completion(.failure(.invalidResponse))
                return
            }
            
            // 记录响应状态码
            self.logger.info("📥 收到响应: \(httpResponse.statusCode)")
            
            // 处理HTTP状态码
            switch httpResponse.statusCode {
            case 200...299:
                // 成功响应
                guard let data = data else {
                    self.logger.error("❌ 响应数据为空")
                    completion(.failure(.invalidResponse))
                    return
                }
                
                // 解析数据
                do {
                    let decodedData = try JSONDecoder().decode(T.self, from: data)
                    self.logger.info("✅ 数据解析成功")
                    completion(.success(decodedData))
                } catch {
                    self.logger.error("❌ 数据解析失败: \(error.localizedDescription)")
                    completion(.failure(.decodingFailed(error)))
                }
                
            case 429:
                // 请求频率限制
                self.logger.error("⚠️ 请求频率超限 (429)")
                completion(.failure(.rateLimited))
                
            case 400...499:
                // 客户端错误
                let message = self.extractErrorMessage(from: data) ?? "客户端请求错误"
                self.logger.error("❌ 客户端错误 (\(httpResponse.statusCode)): \(message)")
                completion(.failure(.serverError(httpResponse.statusCode, message)))
                
            case 500...599:
                // 服务器错误
                let message = self.extractErrorMessage(from: data) ?? "服务器内部错误"
                self.logger.error("❌ 服务器错误 (\(httpResponse.statusCode)): \(message)")
                completion(.failure(.serverError(httpResponse.statusCode, message)))
                
            default:
                // 未知状态码
                self.logger.error("❌ 未知状态码: \(httpResponse.statusCode)")
                completion(.failure(.unknown))
            }
        }
        
        // 启动任务
        task.resume()
    }
    
    // MARK: - 异步请求方法
    @available(iOS 13.0, *)
    func request<T: Decodable>(
        endpoint: String,
        method: String = "GET",
        parameters: [String: Any]? = nil,
        headers: [String: String]? = nil
    ) async -> Result<T, APIError> {
        return await withCheckedContinuation { continuation in
            request(endpoint: endpoint, method: method, parameters: parameters, headers: headers) { (result: Result<T, APIError>) in
                continuation.resume(returning: result)
            }
        }
    }
    
    // MARK: - 辅助方法
    
    // 从错误响应中提取错误消息
    private func extractErrorMessage(from data: Data?) -> String? {
        guard let data = data else { return nil }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // 尝试提取常见的错误字段
                if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
                    return message
                } else if let message = json["message"] as? String {
                    return message
                } else if let error = json["error"] as? String {
                    return error
                }
            }
            
            // 如果无法解析为JSON，尝试解析为字符串
            return String(data: data, encoding: .utf8)
        } catch {
            logger.error("❌ 解析错误消息失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // 指数退避重试
    func retryWithExponentialBackoff<T>(
        maxRetries: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 10.0,
        operation: @escaping () async -> Result<T, APIError>
    ) async -> Result<T, APIError> {
        var retries = 0
        var delay = initialDelay
        
        while true {
            let result = await operation()
            
            switch result {
            case .success:
                return result
            case .failure(let error):
                // 只对特定错误进行重试
                if case .rateLimited = error, retries < maxRetries {
                    retries += 1
                    logger.info("⏱️ 重试 \(retries)/\(maxRetries)，延迟 \(delay) 秒")
                    
                    // 等待延迟时间
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    
                    // 增加延迟时间（指数退避）
                    delay = min(delay * 2, maxDelay)
                    continue
                }
                
                return result
            }
        }
    }
} 