import SwiftUI

private enum AppTab: Hashable { case learn, review, progress }

struct ContentView: View {
    @State private var selectedTab: AppTab = .learn
    var body: some View {
        TabView(selection: $selectedTab) {
            LearnView().tabItem { Label("Обучение", systemImage: "map.fill") }.tag(AppTab.learn)
            ReviewView().tabItem { Label("Повторение", systemImage: "rectangle.stack.fill") }.tag(AppTab.review)
            ProgressDashboardView().tabItem { Label("Прогресс", systemImage: "chart.bar.fill") }.tag(AppTab.progress)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .tint(Color(red: 0.43, green: 0.44, blue: 1.0))
    }
}

private struct LearnView: View {
    @EnvironmentObject private var progress: ProgressStore
    @State private var showingAIGenerator = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("CABIN CREW ENGLISH").font(.caption.weight(.bold)).tracking(1.6).foregroundStyle(.secondary)
                            Text("Твой путь к\nпрофессиональному английскому").font(.system(size: 28, weight: .bold, design: .rounded))
                        }
                        Spacer()
                        Image(systemName: "airplane").font(.system(size: 30, weight: .bold)).foregroundStyle(.white).frame(width: 62, height: 62).background(LinearGradient(colors: [Color.indigo, Color(red: 0.42, green: 0.45, blue: 1)], startPoint: .topLeading, endPoint: .bottomTrailing)).clipShape(Circle())
                    }
                    HStack(spacing: 12) {
                        StatPill(symbol: "flame.fill", value: "\(progress.saved.streak)", label: "дней подряд", tint: .orange)
                        StatPill(symbol: "bolt.fill", value: "\(progress.saved.xp)", label: "XP", tint: .yellow)
                        StatPill(symbol: "checkmark.circle.fill", value: "\(progress.saved.lessonsCompleted)", label: "уроков", tint: .green)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("КУРС CABIN CREW").font(.caption.weight(.bold)).tracking(1.3).foregroundStyle(.secondary)
                        Text("Начни с основ и постепенно переходи к языку реального обслуживания пассажиров.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Button { showingAIGenerator = true } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "sparkles").font(.title2.bold()).foregroundStyle(.white)
                                .frame(width: 52, height: 52).background(Color.indigo).clipShape(RoundedRectangle(cornerRadius: 15))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Создать новые задания с AI").font(.headline).foregroundStyle(.primary)
                                Text("Новые слова, тесты и фразы по выбранной теме").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
                        }.padding(14).background(Color.indigo.opacity(0.10)).clipShape(RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain)

                    ForEach(Array(VocabularyData.units.enumerated()), id: \.element.id) { index, unit in
                        NavigationLink { UnitDetailView(unit: unit) } label: {
                            UnitCard(unit: unit, number: index + 1, completed: progress.saved.lessonsCompleted > index)
                        }.buttonStyle(.plain)
                    }
                    if !progress.generatedPacks.isEmpty {
                        Text("ТВОИ AI-УРОКИ").font(.caption.weight(.bold)).tracking(1.3).foregroundStyle(.secondary).padding(.top, 4)
                        ForEach(Array(progress.generatedPacks.enumerated()), id: \.element.id) { index, pack in
                            NavigationLink { GeneratedUnitDetailView(pack: pack) } label: {
                                UnitCard(unit: pack.unit, number: index + 1, completed: false)
                            }.buttonStyle(.plain)
                        }
                    }
                    Text("Материал помогает изучать английскую лексику. Он не заменяет подготовку, руководства и процедуры конкретной авиакомпании.")
                        .font(.footnote).foregroundStyle(.secondary).padding(.top, 4)
                }.padding(20)
            }
            .background(Color(uiColor: .systemBackground))
            .navigationTitle("Курс")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAIGenerator = true } label: { Image(systemName: "sparkles") }
                        .accessibilityLabel("Создать AI-урок")
                }
            }
        }
        .sheet(isPresented: $showingAIGenerator) {
            AILessonGeneratorView().environmentObject(progress)
        }
    }
}

private struct AILessonGeneratorView: View {
    @EnvironmentObject private var progress: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("cabinCrewEnglish.apiBaseURL") private var baseURL = "https://router.cheap/v1"
    @AppStorage("cabinCrewEnglish.apiModel") private var modelID = ""
    @State private var topic = "Общение с пассажирами во время обслуживания"
    @State private var level = "A2"
    @State private var itemCount = 8
    @State private var isGenerating = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var closeAfterAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Тема урока", text: $topic, axis: .vertical)
                        .lineLimit(2...4)
                    Picker("Уровень", selection: $level) {
                        Text("A2 — базовый").tag("A2")
                        Text("B1 — средний").tag("B1")
                        Text("B1+ — выше среднего").tag("B1+")
                    }
                    Picker("Количество", selection: $itemCount) {
                        Text("6 заданий").tag(6)
                        Text("8 заданий").tag(8)
                        Text("10 заданий").tag(10)
                        Text("12 заданий").tag(12)
                    }
                } header: {
                    Text("Новый урок")
                } footer: {
                    Text("Один запрос создаст карточки слов и столько же новых тестовых заданий. Готовый урок сохранится на iPhone и будет доступен без повторной генерации.")
                }

                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("API-провайдер").font(.headline)
                            Text(baseURL).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            Text(modelID.isEmpty ? "Модель не выбрана" : modelID).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        NavigationLink("Настроить") { AIAPISettingsView() }
                            .font(.subheadline.weight(.semibold))
                    }
                } header: {
                    Text("Подключение")
                }

                Section {
                    Button {
                        Task { await generate() }
                    } label: {
                        HStack {
                            Spacer()
                            if isGenerating { ProgressView().tint(.white) }
                            else { Image(systemName: "sparkles") }
                            Text(isGenerating ? "Создаю задания…" : "Сгенерировать урок")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(isGenerating || topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .listRowBackground(Color.indigo)
                    .foregroundStyle(.white)
                } footer: {
                    Text("Запрос оплачивается по тарифам выбранной модели. Не нажимай кнопку повторно, пока идёт генерация.")
                }

                Section {
                    Label("Ключ хранится в защищённом хранилище iPhone (Keychain).", systemImage: "lock.shield")
                    Label("Сгенерированные задания сохраняются локально.", systemImage: "internaldrive")
                    Label("Генератор не создаёт официальные инструкции по безопасности или действиям экипажа.", systemImage: "info.circle")
                }
            }
            .navigationTitle("AI-задания")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Закрыть") { dismiss() } }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("Готово") {
                    if closeAfterAlert { dismiss() }
                    closeAfterAlert = false
                }
            } message: {
                Text(alertMessage)
            }
        }
    }

    @MainActor
    private func generate() async {
        isGenerating = true
        defer { isGenerating = false }
        do {
            let pack = try await AIExerciseGenerator().generate(
                topic: topic,
                level: level,
                count: itemCount,
                baseURL: baseURL,
                model: modelID,
                apiKey: APIKeychain.load(),
                existingTerms: progress.allItems.map(\.term)
            )
            progress.addGeneratedPack(pack)
            alertTitle = "Урок создан"
            alertMessage = "Новый урок добавлен в раздел «Твои AI-уроки». Он сохранён на этом iPhone."
            closeAfterAlert = true
            showAlert = true
        } catch {
            alertTitle = "Не удалось создать урок"
            alertMessage = error.localizedDescription
            closeAfterAlert = false
            showAlert = true
        }
    }
}

private struct AIAPISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("cabinCrewEnglish.apiBaseURL") private var baseURL = "https://router.cheap/v1"
    @AppStorage("cabinCrewEnglish.apiModel") private var modelID = ""
    @State private var apiKey = APIKeychain.load()
    @State private var showKey = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        Form {
            Section {
                TextField("https://router.cheap/v1", text: $baseURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                TextField("ID модели, например из панели провайдера", text: $modelID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                HStack {
                    Group {
                        if showKey { TextField("API-ключ", text: $apiKey) }
                        else { SecureField("API-ключ", text: $apiKey) }
                    }
                    Button { showKey.toggle() } label: {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                    }.buttonStyle(.plain)
                }
            } header: {
                Text("OpenAI-compatible API")
            } footer: {
                Text("Для Router.cheap используй https://router.cheap/v1. Укажи точный ID модели, доступный твоему API-ключу. Поддерживаются Chat Completions-совместимые провайдеры.")
            }

            Section {
                Button("Сохранить настройки") {
                    do {
                        try APIKeychain.save(apiKey)
                        dismiss()
                    } catch {
                        errorMessage = error.localizedDescription
                        showError = true
                    }
                }
                .disabled(baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Section {
                Text("API-ключ не встраивается в проект и не сохраняется в обычных настройках приложения. Он хранится в Keychain этого устройства.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Настройки API")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Не удалось сохранить ключ", isPresented: $showError) {
            Button("ОК", role: .cancel) { }
        } message: { Text(errorMessage ?? "Неизвестная ошибка") }
    }
}

private struct GeneratedUnitDetailView: View {
    let pack: GeneratedLessonPack
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(pack.unit.subtitle).font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    Label("\(pack.unit.items.count) карточек", systemImage: "rectangle.on.rectangle")
                    Spacer()
                    Label("\(pack.exercises.count) заданий", systemImage: "checkmark.circle")
                }.font(.caption.weight(.semibold))
                Text(pack.unit.level).font(.caption.bold()).foregroundStyle(.indigo)
                NavigationLink {
                    GeneratedLessonView(pack: pack)
                } label: {
                    Label("Начать AI-урок", systemImage: "play.fill")
                        .font(.headline).frame(maxWidth: .infinity).padding()
                        .background(Color.indigo).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain)
                Text("СЛОВА И ВЫРАЖЕНИЯ").font(.caption.bold()).tracking(1.2).foregroundStyle(.secondary)
                ForEach(pack.unit.items) { item in VocabularyRow(item: item) }
                Text("УПРАЖНЕНИЯ").font(.caption.bold()).tracking(1.2).foregroundStyle(.secondary).padding(.top, 5)
                ForEach(Array(pack.exercises.enumerated()), id: \.element.id) { index, exercise in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Задание \(index + 1)").font(.caption.bold()).foregroundStyle(.indigo)
                        Text(exercise.prompt).font(.subheadline.weight(.medium))
                    }.padding(13).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 13))
                }
            }.padding(20)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle(pack.unit.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GeneratedLessonView: View {
    @EnvironmentObject private var progress: ProgressStore
    @Environment(\.dismiss) private var dismiss
    let pack: GeneratedLessonPack
    @State private var questions: [GeneratedExercise] = []
    @State private var options: [String] = []
    @State private var index = 0
    @State private var selectedAnswer: String?
    @State private var answered = false
    @State private var isCorrect = false
    @State private var correctIDs: Set<String> = []
    @State private var showResult = false

    private var current: GeneratedExercise? { index < questions.count ? questions[index] : nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.headline).foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.2))
                        Capsule().fill(Color.indigo)
                            .frame(width: geo.size.width * CGFloat(index) / CGFloat(max(questions.count, 1)))
                    }
                }
                .frame(height: 9)
                Text("\(min(index + 1, max(questions.count, 1)))/\(questions.count)")
                    .font(.caption.bold()).foregroundStyle(.secondary)
                    .fixedSize()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let question = current {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(exerciseLabel(question.type).uppercased())
                                .font(.caption.bold()).tracking(1.1).foregroundStyle(.indigo)
                            Text(question.prompt)
                                .font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
                            if !question.relatedTerm.isEmpty {
                                Text("Тема: \(question.relatedTerm)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)

                        VStack(spacing: 10) {
                            ForEach(options, id: \.self) { option in
                                Button { choose(option, question: question) } label: {
                                    HStack(alignment: .center, spacing: 10) {
                                        Text(option).font(.headline).multilineTextAlignment(.leading)
                                        Spacer(minLength: 5)
                                        if answered && option == question.correctAnswer {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                        } else if answered && option == selectedAnswer {
                                            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                        }
                                    }
                                    .padding(15)
                                    .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                                    .background(optionColor(option, question: question))
                                    .overlay(RoundedRectangle(cornerRadius: 15)
                                        .stroke(optionBorder(option, question: question), lineWidth: 1.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 15))
                                }
                                .buttonStyle(.plain)
                                .disabled(answered)
                            }
                        }

                        if answered {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(isCorrect ? "Правильно!" : "Правильный ответ")
                                    .font(.headline).foregroundStyle(isCorrect ? .green : .orange)
                                Text(question.explanation)
                                    .font(.subheadline).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    } else {
                        ProgressView().tint(.indigo).frame(maxWidth: .infinity).padding(.top, 60)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }

            if current != nil {
                Button { next() } label: {
                    Text(answered ? (index == questions.count - 1 ? "Завершить" : "Продолжить") : "Выбери ответ")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(17)
                        .background(answered ? Color.indigo : Color.gray.opacity(0.25))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!answered)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(Color(uiColor: .systemBackground))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { prepareQuestions() }
        .navigationDestination(isPresented: $showResult) {
            LessonResultView(title: pack.unit.title, count: questions.count, correct: correctIDs.count)
        }
    }

    private func prepareQuestions() {
        if questions.isEmpty { questions = pack.exercises.shuffled() }
        prepareOptions()
    }

    private func prepareOptions() {
        guard let question = current else { return }
        options = question.options.shuffled()
    }

    private func choose(_ option: String, question: GeneratedExercise) {
        guard !answered else { return }
        selectedAnswer = option
        isCorrect = option == question.correctAnswer
        answered = true
        if isCorrect { correctIDs.insert(question.id) }
    }

    private func next() {
        if index >= questions.count - 1 {
            progress.completeGeneratedLesson(pack, correctExerciseIDs: correctIDs)
            showResult = true
            return
        }
        index += 1
        selectedAnswer = nil
        answered = false
        prepareOptions()
    }

    private func optionColor(_ option: String, question: GeneratedExercise) -> Color {
        guard answered else { return Color(uiColor: .secondarySystemBackground) }
        if option == question.correctAnswer { return Color.green.opacity(0.15) }
        if option == selectedAnswer { return Color.red.opacity(0.12) }
        return Color(uiColor: .secondarySystemBackground)
    }

    private func optionBorder(_ option: String, question: GeneratedExercise) -> Color {
        guard answered else { return Color.gray.opacity(0.15) }
        if option == question.correctAnswer { return .green }
        if option == selectedAnswer { return .red }
        return .clear
    }

    private func exerciseLabel(_ type: String) -> String {
        switch type {
        case "choose_phrase": return "Выбери выражение"
        case "complete_sentence": return "Закончи предложение"
        case "choose_response": return "Выбери ответ пассажиру"
        default: return "Выбери правильный вариант"
        }
    }
}

private struct StatPill: View {
    let symbol: String; let value: String; let label: String; let tint: Color
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol).foregroundStyle(tint).font(.title3)
            VStack(alignment: .leading, spacing: 1) { Text(value).font(.headline.bold()); Text(label).font(.caption2).foregroundStyle(.secondary) }
            Spacer(minLength: 0)
        }.padding(12).frame(maxWidth: .infinity).background(Color(uiColor: .secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 15))
    }
}

private struct UnitCard: View {
    let unit: CourseUnit; let number: Int; let completed: Bool
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(LinearGradient(colors: [Color.indigo.opacity(0.95), Color.blue.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 58, height: 58)
                Image(systemName: unit.symbol).font(.title2.bold()).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text("БЛОК \(number) · \(unit.level)").font(.caption2.weight(.bold)).tracking(1).foregroundStyle(.secondary); Spacer(); if completed { Image(systemName: "checkmark.seal.fill").foregroundStyle(.green) } }
                Text(unit.title).font(.headline.weight(.semibold)).foregroundStyle(.primary)
                Text(unit.subtitle).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                Text("\(unit.items.count) слов и выражений").font(.caption2.weight(.medium)).foregroundStyle(Color.indigo)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
        }.padding(14).background(Color(uiColor: .secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct UnitDetailView: View {
    let unit: CourseUnit
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(unit.subtitle).font(.subheadline).foregroundStyle(.secondary)
                HStack { Label("\(unit.items.count) карточек", systemImage: "rectangle.on.rectangle"); Spacer(); Text(unit.level).foregroundStyle(.indigo).bold() }.font(.caption)
                NavigationLink { LessonView(title: unit.title, items: unit.items) } label: {
                    Label("Начать урок", systemImage: "play.fill").font(.headline).frame(maxWidth: .infinity).padding().background(Color.indigo).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain)
                Text("СЛОВА ЭТОГО БЛОКА").font(.caption.bold()).tracking(1.2).foregroundStyle(.secondary).padding(.top, 6)
                ForEach(unit.items) { item in VocabularyRow(item: item) }
            }.padding(20)
        }.background(Color(uiColor: .systemBackground)).navigationTitle(unit.title).navigationBarTitleDisplayMode(.inline)
    }
}

private struct VocabularyRow: View {
    let item: VocabItem
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button { SpeechService.shared.speak(item.term) } label: { Image(systemName: "speaker.wave.2.fill").font(.title3).foregroundStyle(.indigo).frame(width: 38, height: 38).background(Color.indigo.opacity(0.12)).clipShape(Circle()) }.buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.term).font(.headline)
                Text(item.translation).font(.subheadline).foregroundStyle(Color.indigo)
                Text(item.example).font(.subheadline).padding(.top, 3)
                Text(item.exampleTranslation).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(Color(uiColor: .secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct LessonView: View {
    @EnvironmentObject private var progress: ProgressStore
    @Environment(\.dismiss) private var dismiss
    let title: String
    let items: [VocabItem]
    @State private var deck: [VocabItem] = []
    @State private var options: [VocabItem] = []
    @State private var index = 0
    @State private var selectedID: String?
    @State private var answered = false
    @State private var correctIDs: Set<String> = []
    @State private var hearts = 5
    @State private var showResult = false
    @State private var isCorrect = false

    private var current: VocabItem? { index < deck.count ? deck[index] : nil }
    private var directionToEnglish: Bool { index % 3 == 1 }
    private var questionTitle: String {
        switch index % 3 {
        case 1: return "Выбери английское выражение"
        case 2: return "Прослушай и выбери услышанное слово"
        default: return "Что означает это выражение?"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.headline).foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.2))
                        Capsule().fill(Color.indigo)
                            .frame(width: geo.size.width * CGFloat(index) / CGFloat(max(deck.count, 1)))
                    }
                }
                .frame(height: 9)
                Label("\(hearts)", systemImage: "heart.fill")
                    .foregroundStyle(.pink).font(.subheadline.bold()).fixedSize()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let card = current {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("\(index + 1) ИЗ \(deck.count)")
                                .font(.caption.bold()).tracking(1.2).foregroundStyle(.secondary)
                            Text(questionTitle).font(.title2.bold())
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 12) {
                                if index % 3 == 2 {
                                    Button { SpeechService.shared.speak(card.term) } label: {
                                        Label("Прослушать слово", systemImage: "speaker.wave.2.fill")
                                            .font(.title3.bold()).padding(15)
                                            .background(Color.indigo.opacity(0.14))
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Text(directionToEnglish ? card.translation : card.term)
                                        .font(.system(size: 25, weight: .bold, design: .rounded))
                                        .fixedSize(horizontal: false, vertical: true)
                                    if !directionToEnglish {
                                        Button { SpeechService.shared.speak(card.term) } label: {
                                            Image(systemName: "speaker.wave.2.fill").font(.title2).foregroundStyle(.indigo)
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }
                            .padding(.vertical, 14)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 10) {
                            ForEach(options) { option in
                                Button { choose(option) } label: {
                                    HStack(spacing: 10) {
                                        Text((directionToEnglish || index % 3 == 2) ? option.term : option.translation)
                                            .font(.headline).multilineTextAlignment(.leading)
                                        Spacer(minLength: 5)
                                        if answered && option.id == card.id {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                        } else if answered && selectedID == option.id && option.id != card.id {
                                            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                        }
                                    }
                                    .padding(15)
                                    .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                                    .background(optionBackground(option, correct: card))
                                    .overlay(RoundedRectangle(cornerRadius: 15)
                                        .stroke(optionBorder(option, correct: card), lineWidth: 1.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 15))
                                }
                                .buttonStyle(.plain)
                                .disabled(answered)
                            }
                        }

                        if answered {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(isCorrect ? "Отлично!" : "Правильный ответ")
                                    .font(.headline).foregroundStyle(isCorrect ? .green : .orange)
                                Text(card.term + " — " + card.translation).font(.subheadline.bold())
                                Text(card.example).font(.subheadline)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    } else {
                        ProgressView().tint(.indigo).frame(maxWidth: .infinity).padding(.top, 60)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }

            if current != nil {
                Button { next() } label: {
                    Text(answered ? (index == deck.count - 1 || hearts == 0 ? "Завершить" : "Продолжить") : "Выбери ответ")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(17)
                        .background(answered ? Color.indigo : Color.gray.opacity(0.25))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!answered)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(Color(uiColor: .systemBackground))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { prepareDeck() }
        .navigationDestination(isPresented: $showResult) {
            LessonResultView(title: title, count: deck.count, correct: correctIDs.count)
        }
    }

    private func prepareDeck() {
        if deck.isEmpty { deck = Array(items.shuffled().prefix(min(8, items.count))) }
        prepareOptions()
    }
    private func prepareOptions() {
        guard let card = current else { return }
        var pool = (items + progress.allItems.filter { $0.unitID != card.unitID }).filter { $0.id != card.id }
        pool.shuffle()
        options = ([card] + Array(pool.prefix(3))).shuffled()
    }
    private func choose(_ option: VocabItem) {
        guard let card = current, !answered else { return }
        selectedID = option.id
        isCorrect = option.id == card.id
        answered = true
        if isCorrect { correctIDs.insert(card.id) } else { hearts = max(0, hearts - 1) }
    }
    private func next() {
        if index >= deck.count - 1 || hearts == 0 {
            progress.completeLesson(items: deck, correctIDs: correctIDs)
            showResult = true
            return
        }
        index += 1; answered = false; selectedID = nil; prepareOptions()
    }
    private func optionBackground(_ option: VocabItem, correct: VocabItem) -> Color {
        guard answered else { return Color(uiColor: .secondarySystemBackground) }
        if option.id == correct.id { return Color.green.opacity(0.16) }
        if option.id == selectedID { return Color.red.opacity(0.14) }
        return Color(uiColor: .secondarySystemBackground)
    }
    private func optionBorder(_ option: VocabItem, correct: VocabItem) -> Color {
        guard answered else { return Color.gray.opacity(0.15) }
        if option.id == correct.id { return .green }
        if option.id == selectedID { return .red }
        return .clear
    }
}

private struct LessonResultView: View {
    @EnvironmentObject private var progress: ProgressStore
    @Environment(\.dismiss) private var dismiss
    let title: String; let count: Int; let correct: Int
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "star.circle.fill").font(.system(size: 76)).foregroundStyle(.yellow)
            Text("Урок завершён!").font(.largeTitle.bold())
            Text(title).font(.headline).foregroundStyle(.secondary)
            HStack(spacing: 26) { ResultMetric(value: "\(correct)/\(count)", label: "верно"); ResultMetric(value: "+\(10 + correct * 2)", label: "XP"); ResultMetric(value: "\(progress.saved.streak)", label: "серия") }
            Text("Слова добавлены в систему интервального повторения. Возвращайся к ним, чтобы закрепить результат.").multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal)
            Spacer()
            Button { dismiss() } label: { Text("Продолжить").font(.headline).frame(maxWidth: .infinity).padding(17).background(Color.indigo).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 16)) }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.hidden, for: .navigationBar)
    }
}
private struct ResultMetric: View {
    let value: String; let label: String
    var body: some View { VStack(spacing: 3) { Text(value).font(.title2.bold()); Text(label).font(.caption).foregroundStyle(.secondary) } }
}

private struct ReviewView: View {
    @EnvironmentObject private var progress: ProgressStore
    @State private var showingReview = false
    private var due: [VocabItem] { Array(progress.dueItems.prefix(30)) }
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) { Text("Повторение слов").font(.largeTitle.bold()); Text("Сложные слова возвращаются чаще, знакомые — реже.").foregroundStyle(.secondary) }
                HStack { Label("\(due.count) к повторению", systemImage: "clock"); Spacer(); Text("Интервальная система").font(.caption).foregroundStyle(.secondary) }.font(.subheadline.bold())
                if due.isEmpty {
                    VStack(spacing: 12) { Image(systemName: "checkmark.seal.fill").font(.system(size: 48)).foregroundStyle(.green); Text("Пока всё повторено").font(.title3.bold()); Text("Продолжай изучать новые блоки — слова появятся здесь, когда придёт время повторения.").multilineTextAlignment(.center).foregroundStyle(.secondary) }.frame(maxWidth: .infinity).padding(.vertical, 40)
                } else {
                    NavigationLink { LessonView(title: "Повторение", items: due) } label: {
                        Label("Начать повторение", systemImage: "play.fill").font(.headline).frame(maxWidth: .infinity).padding(16).background(Color.indigo).foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 16))
                    }.buttonStyle(.plain)
                    ScrollView { ForEach(due) { VocabularyRow(item: $0) } }
                }
                Spacer(minLength: 0)
            }.padding(20).navigationTitle("Повторение").navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ProgressDashboardView: View {
    @EnvironmentObject private var progress: ProgressStore
    private var learned: Int { progress.saved.words.values.filter { $0.box >= 3 }.count }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Твой прогресс").font(.largeTitle.bold())
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        DashboardTile(title: "Опыт", value: "\(progress.saved.xp) XP", icon: "bolt.fill", tint: .yellow)
                        DashboardTile(title: "Занятия", value: "\(progress.saved.lessonsCompleted)", icon: "checkmark.circle.fill", tint: .green)
                        DashboardTile(title: "Серия", value: "\(progress.saved.streak) дней", icon: "flame.fill", tint: .orange)
                        DashboardTile(title: "Закреплено", value: "\(learned) слов", icon: "brain.head.profile", tint: .purple)
                    }
                    VStack(alignment: .leading, spacing: 10) { Text("КАК УСТРОЕНО ПОВТОРЕНИЕ").font(.caption.bold()).tracking(1.2).foregroundStyle(.secondary); Text("После правильных ответов слово постепенно переходит на более длинный интервал: 1, 3, 7, 14 и 30 дней. Ошибки возвращают его в начало очереди.").font(.subheadline).foregroundStyle(.secondary) }.padding(16).background(Color(uiColor: .secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 16))
                    Text("Все данные хранятся локально на этом iPhone.").font(.footnote).foregroundStyle(.secondary)
                }.padding(20)
            }.background(Color(uiColor: .systemBackground)).navigationTitle("Статистика").navigationBarTitleDisplayMode(.inline)
        }
    }
}
private struct DashboardTile: View {
    let title: String; let value: String; let icon: String; let tint: Color
    var body: some View { VStack(alignment: .leading, spacing: 12) { Image(systemName: icon).font(.title2).foregroundStyle(tint); Text(value).font(.title2.bold()); Text(title).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(Color(uiColor: .secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 17)) }
}
