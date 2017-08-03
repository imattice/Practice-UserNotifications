/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish, 
 * distribute, sublicense, create a derivative work, and/or sell copies of the 
 * Software in any work that is designed, intended, or marketed for pedagogical or 
 * instructional purposes related to programming, coding, application development, 
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works, 
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
import UIKit
import SafariServices
import UserNotifications

fileprivate let viewActionIdentifier = "VIEW_IDENTIFIER"
fileprivate let newsCategoryIdentifier = "NEWS_CATEGORY"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  
  var window: UIWindow?
  
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    
    UITabBar.appearance().barTintColor = UIColor.themeGreenColor
    UITabBar.appearance().tintColor = UIColor.white
    registerForPushNotifications()
    
//    check if launched from notification
//    if the remoteNotification exists in launchOptions, this will be the notification payload we will use
    if let notification = launchOptions?[.remoteNotification] as? [String: AnyObject] {
        
//        create a NewsItem using the anticipated payload and refresh the news table
        let aps = notification["aps"] as! [String: AnyObject]
        _ = NewsItem.makeNewsItem(aps)
        
//        change the selected tab to the news section
        (window?.rootViewController as? UITabBarController)?.selectedIndex = 1
    }
    
    return true
  }
    
//  requests the user for permission to send notifications
    func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (granted, error) in
            print("Permission granted: \(granted)")
            
            guard granted else { return }
            
//            create the notification action that opens the app in the foreground when triggered.  The identifier is unique, which is used to differentiate between other actions with the same notification
            let viewAction = UNNotificationAction(identifier: viewActionIdentifier, title: "View", options: [.foreground])
            
//            define the news category, which contains the above action.  it also has a unique identifierm which the payload will need to contain to specify, that the push notification belongs to this category
            let newsCategory = UNNotificationCategory(identifier: newsCategoryIdentifier, actions: [viewAction], intentIdentifiers: [], options: [])
            
//            register the actionable notification
            UNUserNotificationCenter.current().setNotificationCategories([newsCategory])
            
            self.getNotificationSettings()
            
        }
    }
//    returns the settings that the user has granted, rather than the settings that are requested
    func getNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            print("Notification settings: \(settings)")
            
            guard settings.authorizationStatus == .authorized else { return }
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data -> String in
            return String(format: "%02.2hhx", data)
        }
        let token = tokenParts.joined()
        print("Device Token: \(token)")
    }
    
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register: \(error)")
    }
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        let aps = userInfo["aps"] as! [String: AnyObject]

//        check if "content-available" is set to 1 to see if the notification is silent or not
        if aps["content-available"] as? Int == 1 {
            let podcastStore = PodcastStore.sharedStore
            //Refresh Podcast list, which is an async network call
            podcastStore.refreshItems { didLoadNewItems in
//                once the list has been refreshed, call the completion handler and let the system know if any new data was loaded
                completionHandler(didLoadNewItems ? .newData : .noData)
            }
        } else {
//            if the notification isn't silent, assume that it is news and create a news item
            _ = NewsItem.makeNewsItem(aps)
            completionHandler(.newData)
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
//        get the directory
        let aps = userInfo["aps"] as! [String: AnyObject]
        
//        create a newsItem and navigate to the News tab
        if let newsItem = NewsItem.makeNewsItem(aps) {
            (window?.rootViewController as? UITabBarController)?.selectedIndex = 1
            
//            check the action identifier for the view action and ensure the link url is valid, then display the link in safari
            if response.actionIdentifier == viewActionIdentifier, let url = URL(string: newsItem.link) {
                let safari = SFSafariViewController(url: url)
                window?.rootViewController?.present(safari, animated: true, completion: nil)
            }
        }
        completionHandler()
    }
}

