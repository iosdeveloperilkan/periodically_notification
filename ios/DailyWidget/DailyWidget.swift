//
//  DailyWidget.swift
//  DailyWidget Extension
//
//  iOS WidgetKit widget for displaying daily content
//

import WidgetKit
import SwiftUI

struct DailyWidget: Widget {
    let kind: String = "DailyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyWidgetProvider()) { entry in
            DailyWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Günlük İçerik")
        .description("Günlük içerikleri ana ekranda görüntüleyin.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DailyWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let body: String
    let updatedAt: String?
}

struct DailyWidgetProvider: TimelineProvider {
    typealias Entry = DailyWidgetEntry
    
    func placeholder(in context: Context) -> DailyWidgetEntry {
        DailyWidgetEntry(
            date: Date(),
            title: "Günün İçeriği",
            body: "Örnek içerik metni burada görünecek...",
            updatedAt: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyWidgetEntry) -> ()) {
        let entry = loadWidgetData()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = loadWidgetData()
        
        // Refresh every hour (best-effort)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func loadWidgetData() -> DailyWidgetEntry {
        let userDefaults = UserDefaults(suiteName: "group.com.example.periodicallynotification")
        
        let title = userDefaults?.string(forKey: "widget_title") ?? "Günün İçeriği"
        let body = userDefaults?.string(forKey: "widget_body") ?? "İçerik yükleniyor..."
        let updatedAt = userDefaults?.string(forKey: "widget_updatedAt")
        
        return DailyWidgetEntry(
            date: Date(),
            title: title,
            body: body,
            updatedAt: updatedAt
        )
    }
}

struct DailyWidgetEntryView: View {
    var entry: DailyWidgetProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(2)
            
            Text(entry.body)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            if let updatedAt = entry.updatedAt {
                Text(formatDate(updatedAt))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.38, green: 0.0, blue: 0.93), Color(red: 0.5, green: 0.2, blue: 0.95)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: isoString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "dd/MM/yyyy HH:mm"
            return "Son güncelleme: \(displayFormatter.string(from: date))"
        }
        
        return ""
    }
}

struct DailyWidget_Previews: PreviewProvider {
    static var previews: some View {
        DailyWidgetEntryView(
            entry: DailyWidgetEntry(
                date: Date(),
                title: "Günün İçeriği",
                body: "Bu bir örnek içerik metnidir. Widget'ta görüntülenecek içerik burada yer alacak.",
                updatedAt: "2024-01-15T09:00:00.000Z"
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}


