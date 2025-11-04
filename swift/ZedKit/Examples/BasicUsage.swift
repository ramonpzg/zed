import Foundation
import ZedKit

/// Example demonstrating basic usage of ZedKit
///
/// This example shows how to:
/// 1. Create credentials
/// 2. Initialize the thread manager
/// 3. Fetch threads from the server
/// 4. Create a new thread
/// 5. Update an existing thread
/// 6. Delete a thread
///
/// To run this example:
/// 1. Replace userId and accessToken with your actual credentials
/// 2. Run: swift run BasicUsage

@main
struct BasicUsageExample {
    static func main() async throws {
        print("ZedKit Basic Usage Example")
        print("Version: \(ZedKit.version)")
        print()

        // MARK: 1. Create Credentials

        // TODO: Replace with your actual credentials
        // You can get these from Zed desktop app or authentication flow
        let credentials = ZedCredentials(
            userId: 123,  // Your Zed user ID
            accessToken: "your_access_token_here"
        )

        // MARK: 2. Initialize Thread Manager

        let threadManager = ZedKit.createThreadManager(
            credentials: credentials,
            configuration: .production  // or .staging, .local()
        )

        // MARK: 3. Fetch Threads

        print("Fetching threads...")
        do {
            try await threadManager.fetchThreads()
            let threads = await threadManager.threads

            print("Found \(threads.count) threads:")
            for thread in threads {
                print("  - \(thread.title) (updated: \(thread.updatedAt))")
            }
            print()
        } catch {
            print("Error fetching threads: \(error)")
            return
        }

        // MARK: 4. Create a New Thread

        print("Creating a new thread...")
        let threadContent = """
        {
            "version": "0.4.0",
            "messages": [
                {
                    "role": "user",
                    "content": "Hello from ZedKit!"
                }
            ]
        }
        """

        guard let threadData = threadContent.data(using: .utf8) else {
            print("Failed to create thread data")
            return
        }

        do {
            let newThreadId = try await threadManager.createThread(
                type: .text,
                title: "My First iOS Thread",
                summary: "Created from iOS using ZedKit",
                data: threadData
            )

            print("Created thread with ID: \(newThreadId)")
            print()
        } catch {
            print("Error creating thread: \(error)")
            return
        }

        // MARK: 5. Update a Thread

        print("Updating thread...")
        if let firstThread = await threadManager.threads.first {
            do {
                try await threadManager.updateThread(
                    id: firstThread.id,
                    title: "Updated Title",
                    summary: "This thread was updated from iOS"
                )

                print("Updated thread: \(firstThread.id)")
                print()
            } catch {
                print("Error updating thread: \(error)")
            }
        }

        // MARK: 6. Get Full Thread Data

        if let firstThread = await threadManager.threads.first {
            print("Fetching full thread data...")
            do {
                let threadData = try await threadManager.getThread(id: firstThread.id)
                let decodedData = try await threadManager.decodeThreadData(threadData)

                if let content = String(data: decodedData, encoding: .utf8) {
                    print("Thread content:")
                    print(content)
                    print()
                }
            } catch {
                print("Error fetching thread data: \(error)")
            }
        }

        // MARK: 7. Delete a Thread (Optional)

        // Uncomment to test deletion
        /*
        if let firstThread = await threadManager.threads.first {
            print("Deleting thread...")
            do {
                try await threadManager.deleteThread(id: firstThread.id)
                print("Deleted thread: \(firstThread.id)")
            } catch {
                print("Error deleting thread: \(error)")
            }
        }
        */

        print("Example completed!")
    }
}
