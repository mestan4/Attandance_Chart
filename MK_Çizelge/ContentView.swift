import SwiftUI

// MARK: - 1. MODELLER
struct PointLog: Identifiable, Codable {
    var id = UUID()
    var eventName: String
    var points: Int
    var date = Date()
}

struct Member: Identifiable, Codable {
    var id = UUID()
    var name: String
    var points: Int = 0
    var history: [PointLog] = []
}

struct Event: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var points: Int
    var emoji: String
}

// MARK: - 2. VERİ SAKLAMA
class DataStore {
    static let memberKey = "members_final_v15" // Versiyon güncellendi
    static let eventKey = "events_final_v15"
    
    static func saveMembers(_ members: [Member]) {
        if let data = try? JSONEncoder().encode(members) {
            UserDefaults.standard.set(data, forKey: memberKey)
        }
    }
    
    static func loadMembers() -> [Member] {
        if let data = UserDefaults.standard.data(forKey: memberKey),
           let decoded = try? JSONDecoder().decode([Member].self, from: data) {
            return decoded
        }
        return []
    }

    static func saveEvents(_ events: [Event]) {
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: eventKey)
        }
    }
    
    static func loadEvents() -> [Event] {
        if let data = UserDefaults.standard.data(forKey: eventKey),
           let decoded = try? JSONDecoder().decode([Event].self, from: data) {
            return decoded
        }
        return [
            Event(name: "Üniversiteli", points: 4, emoji: "🎓"),
            Event(name: "Vefa Buluşması", points: 3, emoji: "🤝"),
            Event(name: "Sempozyum", points: 2, emoji: "🎤"),
            Event(name: "Karaoke", points: 1, emoji: "🎶")
        ]
    }
}

// MARK: - 3. ANA GÖRÜNÜM
struct ContentView: View {
    @State private var members: [Member] = DataStore.loadMembers()
    @State private var events: [Event] = DataStore.loadEvents()
    @State private var selectedEvent: Event?
    
    @State private var newMemberName = ""
    @State private var showingAddEvent = false
    @State private var newEventName = ""
    @State private var newEventPoints = ""
    @State private var newEventEmoji = "⭐"
    
    @State private var showingResetAlert = false
    @State private var showingDeleteAlert = false
    @State private var targetMember: Member?
    
    @State private var selectedMemberForHistory: Member?

    var sortedMembers: [Member] {
        members.sorted { $0.points > $1.points }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                // MARK: Etkinlik Seç
                VStack(alignment: .leading, spacing: 10) {
                    Text("Etkinlik Seç").font(.caption).fontWeight(.bold).foregroundColor(.secondary).padding(.horizontal)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(events) { event in
                                EventCard(event: event, isSelected: selectedEvent?.id == event.id)
                                    .onTapGesture { withAnimation { selectedEvent = event } }
                                    .contextMenu {
                                        Button(role: .destructive) { deleteEvent(event) } label: { Label("Etkinliği Sil", systemImage: "trash") }
                                    }
                            }
                            Button(action: { showingAddEvent = true }) { EventAddCard() }
                        }.padding(.horizontal)
                    }
                }.padding(.vertical).background(Color(uiColor: .systemGroupedBackground))

                // MARK: Liste
                List {
                    Section(header: Text("🏆 Sıralama").font(.headline)) {
                        ForEach(sortedMembers) { member in
                            MemberRowView(
                                index: sortedMembers.firstIndex(where: { $0.id == member.id }) ?? 0,
                                member: member
                            ) { addPoint(to: member) }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    targetMember = member
                                    showingDeleteAlert = true
                                } label: { Label("Sil", systemImage: "trash") }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    selectedMemberForHistory = member
                                } label: { Label("Geçmiş", systemImage: "clock.arrow.circlepath") }.tint(.orange)
                            }
                        }
                    }
                }.listStyle(InsetGroupedListStyle())

                // MARK: Alt Bar
                HStack(spacing: 15) {
                    TextField("Yeni Üye Adı", text: $newMemberName).textFieldStyle(.plain).padding(12)
                        .background(Color(uiColor: .secondarySystemGroupedBackground)).cornerRadius(12)
                    Button(action: addNewMember) { Image(systemName: "person.badge.plus.fill").font(.title2).foregroundColor(.blue) }
                }.padding().background(.ultraThinMaterial)
            }
            .navigationTitle("Müzik Kulübü")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { if selectedEvent == nil { selectedEvent = events.first } }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: exportToExcel) { Label("Excel Aktar", systemImage: "tablecells") }
                        Divider()
                        Button(role: .destructive) { showingResetAlert = true } label: { Label("Sıfırla", systemImage: "arrow.counterclockwise") }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(item: $selectedMemberForHistory) { member in
                HistoryView(member: member) { updatedMember in
                    if let index = members.firstIndex(where: { $0.id == updatedMember.id }) {
                        members[index] = updatedMember
                        DataStore.saveMembers(members)
                    }
                }
            }
            .sheet(isPresented: $showingAddEvent) {
                AddEventView(name: $newEventName, points: $newEventPoints, emoji: $newEventEmoji, onSave: saveNewEvent, onCancel: { showingAddEvent = false })
            }
            .alert("Üyeyi Sil", isPresented: $showingDeleteAlert) {
                Button("Sil", role: .destructive) { if let m = targetMember { deleteMember(m) } }
                Button("İptal", role: .cancel) { }
            }
            .alert("Sıfırla", isPresented: $showingResetAlert) {
                Button("Sıfırla", role: .destructive) { resetPoints() }
                Button("İptal", role: .cancel) { }
            }
        }
    }

    // MARK: - FONKSİYONLAR
    func addPoint(to member: Member) {
        guard let event = selectedEvent else { return }
        if let index = members.firstIndex(where: { $0.id == member.id }) {
            withAnimation {
                members[index].points += event.points
                members[index].history.insert(PointLog(eventName: event.name, points: event.points), at: 0)
                DataStore.saveMembers(members)
            }
        }
    }

    func deleteMember(_ member: Member) {
        withAnimation { members.removeAll { $0.id == member.id }; DataStore.saveMembers(members) }
    }

    func deleteEvent(_ event: Event) {
        withAnimation { events.removeAll { $0.id == event.id }; DataStore.saveEvents(events) }
    }

    func addNewMember() {
        if !newMemberName.isEmpty {
            members.append(Member(name: newMemberName))
            newMemberName = ""; DataStore.saveMembers(members)
        }
    }

    func resetPoints() {
        withAnimation {
            for i in members.indices { members[i].points = 0; members[i].history = [] }
            DataStore.saveMembers(members)
        }
    }
    
    func saveNewEvent() {
        if let p = Int(newEventPoints), !newEventName.isEmpty {
            events.append(Event(name: newEventName, points: p, emoji: newEventEmoji))
            DataStore.saveEvents(events); showingAddEvent = false
        }
    }
    
    func exportToExcel() {
        var csvString = "Sira,Isim,Toplam Puan\n"
        for (index, m) in sortedMembers.enumerated() { csvString += "\(index+1),\(m.name),\(m.points)\n" }
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Kulup_Siralama.csv")
        try? csvString.write(to: path, atomically: true, encoding: .utf8)
        let av = UIActivityViewController(activityItems: [path], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            av.popoverPresentationController?.sourceView = rootVC.view
            rootVC.present(av, animated: true)
        }
    }
}

// MARK: - GEÇMİŞ GÖRÜNÜMÜ (DOĞRU PUAN SİLME BURADA)
struct HistoryView: View {
    @State var member: Member
    var onUpdate: (Member) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(member.history) { log in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(log.eventName).fontWeight(.bold)
                            Text(log.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("+\(log.points)").foregroundColor(.green).bold()
                    }
                }
                .onDelete(perform: deleteLog)
            }
            .navigationTitle("\(member.name) Geçmişi")
            .toolbar {
                Button("Tamam") {
                    onUpdate(member)
                    dismiss()
                }
            }
            .overlay {
                if member.history.isEmpty {
                    ContentUnavailableView("Geçmiş Boş", systemImage: "clock")
                }
            }
        }
    }
    
    // MARK: KRİTİK DÜZELTME - SİLİNEN SATIRIN PUANINI HESAPLAR
    func deleteLog(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                // Silinecek kaydın puanını al
                let pointsToDelete = member.history[index].points
                // Üyenin toplam puanından SADECE o kaydın puanını düş
                member.points -= pointsToDelete
                // Kaydı geçmişten sil
                member.history.remove(at: index)
            }
        }
    }
}

// MARK: - TASARIM BİLEŞENLERİ
struct EventCard: View {
    let event: Event; let isSelected: Bool
    var body: some View {
        VStack(spacing: 8) {
            Text(event.emoji).font(.title)
            Text(event.name).font(.caption).fontWeight(.bold).lineLimit(1)
            Text("\(event.points) Puan").font(.system(size: 10)).opacity(0.8)
        }
        .frame(width: 115, height: 100)
        .background(isSelected ? Color.blue : Color(uiColor: .secondarySystemGroupedBackground))
        .foregroundColor(isSelected ? .white : .primary).cornerRadius(16)
    }
}

struct EventAddCard: View {
    var body: some View {
        VStack(spacing: 8) { Image(systemName: "plus.circle.fill").font(.title); Text("Yeni").font(.caption).fontWeight(.bold) }
        .frame(width: 115, height: 100).background(Color.green.opacity(0.1)).foregroundColor(.green).cornerRadius(16)
    }
}

struct MemberRowView: View {
    let index: Int; let member: Member; let onAdd: () -> Void
    var body: some View {
        HStack(spacing: 15) {
            Text(index < 3 ? ["🥇", "🥈", "🥉"][index] : "\(index + 1)").font(.headline).frame(width: 30)
            Text(member.name).font(.body).fontWeight(.medium)
            Spacer()
            Text("\(member.points) p").font(.subheadline).foregroundColor(.gray).bold()
            Button(action: onAdd) { Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.green) }.buttonStyle(BorderlessButtonStyle())
        }.padding(.vertical, 4)
    }
}

struct AddEventView: View {
    @Binding var name: String; @Binding var points: String; @Binding var emoji: String
    var onSave: () -> Void; var onCancel: () -> Void
    let emojis = ["⭐", "🎵", "🎤", "🎓", "🤝", "🍕", "🎸", "📚", "🏆", "🔥"]
    var body: some View {
        NavigationStack {
            Form {
                Section("Etkinlik") { TextField("Ad", text: $name); TextField("Puan", text: $points).keyboardType(.numberPad) }
                Section("Emoji") {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(emojis, id: \.self) { e in
                                Text(e).font(.title).padding(8).background(emoji == e ? Color.blue.opacity(0.2) : Color.clear).cornerRadius(10).onTapGesture { emoji = e }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Yeni Etkinlik")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) { Button("Ekle", action: onSave) }
            }
        }
    }
}

#Preview { ContentView() }
