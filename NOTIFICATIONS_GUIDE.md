## Obavijesti Feature - Quick Reference Guide

### How Notifications Are Fetched

**Automatic Fetching:**
1. When user logs in with valid credentials → notifications auto-fetch
2. When app starts with saved session → notifications auto-fetch on init
3. User can pull-to-refresh on home page
4. User can tap refresh button in AppBar

### Integration Points

#### In AuthProvider
```dart
// Notifications are automatically fetched after login
void login(String username, String password) async {
  // ... authentication logic ...
  if (response.statusCode == 302 && cookie != null) {
    state = AuthState.authenticated;
    await _fetchNotifications(); // ← Auto-fetch
  }
}

// Public method for manual refresh
Future<void> refreshNotifications() async {
  await _fetchNotifications();
}
```

#### In HomePage
```dart
// Refresh on page load
@override
void initState() {
  super.initState();
  Future.microtask(() {
    context.read<AuthProvider>().refreshNotifications();
  });
}

// Display notifications
authProvider.notifications.isEmpty
    ? NotificationsEmptyWidget(...)
    : ListView.builder(
        itemCount: authProvider.notifications.length,
        itemBuilder: (context, index) {
          return NotificationCard(
            notification: authProvider.notifications[index],
          );
        },
      )
```

### Notification Model Structure

```dart
Notification {
  id: String,              // Unique identifier
  title: String,           // "Nastava za 08.04."
  content: String,         // Preview/abstract text
  dateTime: DateTime,      // 2026-04-07 11:27
  subject: String,         // "Kompjuterska grafika"
  author: String,          // "Senad Rahimić"
  authorEmail: String,     // "senad.Rahimic@unmo.ba"
}
```

### HTML Parsing Details

The NotificationService parses HTML from `https://www.fit.ba/student/default.aspx`

**Expected HTML Structure:**
```html
<ul class="newslist">
  <li>
    <table>
      <tr>
        <td>
          <a class="linkButton" href="...">Notification Title</a>
          <span class="meta">07.04.2026 11:27 -</span>
          <span class="meta">Subject Name</span>
          <a href="mailto:author@email.com">Author Name</a>
        </td>
      </tr>
    </table>
    <div class="abstract">Notification content preview...</div>
  </li>
</ul>
```

### Date Format Handling

Input format from HTML: `"07.04.2026 11:27 -"`
- Day: 07
- Month: 04
- Year: 2026
- Hour: 11
- Minute: 27

Output: `DateTime(2026, 04, 07, 11, 27)`

Display format in UI: `"07.04.2026 11:27"` (using `intl` package)

### Error Handling

- Network timeout: 10 seconds
- HTML parsing errors: Skipped items continue processing
- Empty lists: Shows "Nema obavijesti" message
- Failed refresh: Silently fails and keeps existing data

### Customization

#### Change Empty State Message
Edit `notifications_empty_widget.dart`:
```dart
Text(
  "Nema dostupnih obavijesti",  // ← Change this
  style: TextStyle(...),
)
```

#### Change Notification Card Layout
Edit `notification_card.dart` in the `build()` method:
```dart
NotificationCard(
  notification: notification,
  onTap: () {
    // TODO: Implement custom tap behavior
  },
)
```

#### Add More Fields to Notification
1. Add field to `Notification` class in `models/notification.dart`
2. Update `NotificationService.parseNotificationsFromHtml()` to extract it
3. Display in `NotificationCard` widget

### Testing the Feature

1. **Test Auto-Login Fetch:**
   - Clear app data
   - Login with valid credentials
   - Notifications should appear in 2-3 seconds

2. **Test App Start Fetch:**
   - Login once (saves cookie)
   - Close and reopen app
   - Notifications should load automatically

3. **Test Manual Refresh:**
   - Tap refresh button in AppBar
   - Or pull-to-refresh on notifications list

4. **Test Empty State:**
   - Mock empty HTML response
   - Should show "Nema obavijesti" message with retry button

### Debugging

Enable debug prints in `auth_provider.dart`:
```dart
debugPrint("Notifications: ${_notifications.length}");
debugPrint("State: $state");
```

Check HTML parsing in `notification_service.dart`:
```dart
debugPrint("Found ${newsItems.length} notification items");
```

