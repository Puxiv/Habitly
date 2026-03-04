import Foundation
import Observation

// MARK: - App Language

enum AppLanguage: String, CaseIterable {
    case english      = "en"
    case bulgarian    = "bg"
    case northwestern = "nw"   // Български Пустиняк dialect (Враца / Монтана) 🌾
    case shopluk      = "sh"   // Български Винкел dialect (Перник / Земен) ⚒️
    case plovdiv      = "pd"   // Български Майна dialect (Пловдив / Тракия) 🍷
    case burgas       = "bs"   // Български Батка dialect (Бургас / Черноморие) 🌊

    var displayName: String {
        switch self {
        case .english:      return "English"
        case .bulgarian:    return "Български"
        case .northwestern: return "Български Пустиняк 🌾"
        case .shopluk:      return "Български Винкел ⚒️"
        case .plovdiv:      return "Български Майна 🍷"
        case .burgas:       return "Български Батка 🌊"
        }
    }
}

// MARK: - Language Manager

@MainActor @Observable final class LanguageManager {
    static let shared = LanguageManager()

    var current: AppLanguage {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: "appLanguage") }
    }

    /// The user-configurable AI assistant name (default: Пучо / Pucho)
    var aiName: String {
        didSet { UserDefaults.standard.set(aiName, forKey: "ai_assistant_name") }
    }

    /// Auto-speak AI responses aloud
    var autoSpeak: Bool {
        didSet { UserDefaults.standard.set(autoSpeak, forKey: "auto_speak") }
    }

    // MARK: - Module Toggles (all default ON)
    var moduleHabits: Bool {
        didSet { UserDefaults.standard.set(moduleHabits, forKey: "module_habits") }
    }
    var moduleReminders: Bool {
        didSet { UserDefaults.standard.set(moduleReminders, forKey: "module_reminders") }
    }
    var moduleStuff: Bool {
        didSet { UserDefaults.standard.set(moduleStuff, forKey: "module_stuff") }
    }
    var moduleHealth: Bool {
        didSet { UserDefaults.standard.set(moduleHealth, forKey: "module_health") }
    }
    var moduleStocks: Bool {
        didSet { UserDefaults.standard.set(moduleStocks, forKey: "module_stocks") }
    }
    var moduleNews: Bool {
        didSet { UserDefaults.standard.set(moduleNews, forKey: "module_news") }
    }

    private static func loadBool(_ key: String, default defaultValue: Bool = true) -> Bool {
        UserDefaults.standard.object(forKey: key) == nil ? defaultValue : UserDefaults.standard.bool(forKey: key)
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        self.current = AppLanguage(rawValue: saved) ?? .english
        self.aiName = UserDefaults.standard.string(forKey: "ai_assistant_name") ?? "Pucho"
        self.autoSpeak = Self.loadBool("auto_speak")
        self.moduleHabits = Self.loadBool("module_habits")
        self.moduleReminders = Self.loadBool("module_reminders")
        self.moduleStuff = Self.loadBool("module_stuff")
        self.moduleHealth = Self.loadBool("module_health")
        self.moduleStocks = Self.loadBool("module_stocks")
        self.moduleNews = Self.loadBool("module_news")
    }

    /// Pick the right string for the current language.
    func t(_ en: String, _ bg: String, _ nw: String, _ sh: String, _ pd: String, _ bs: String) -> String {
        switch current {
        case .english:      return en
        case .bulgarian:    return bg
        case .northwestern: return nw
        case .shopluk:      return sh
        case .plovdiv:      return pd
        case .burgas:       return bs
        }
    }
}

// MARK: - All Translated Strings

extension LanguageManager {

    // MARK: Tabs & Nav
    var habitsTab:    String { t("Habits",   "Навици",     "Навик",      "Навиките",   "Навици",     "Навици") }
    var progressTab:  String { t("Progress", "Прогрес",    "Напредък",   "Шо съм постигнал", "Прогрес", "Прогрес") }
    var settings:     String { t("Settings", "Настройки",  "Наредби",    "Настройки",  "Настройки",  "Настройки") }
    var language:     String { t("Language", "Език",       "Език",       "Жезика",     "Език",       "Език") }

    // MARK: Common Actions
    var done:   String { t("Done",   "Готово",      "Готово бе!",   "Арно!",       "Готово бе!",   "Арно де!") }
    var cancel: String { t("Cancel", "Отказ",       "Остави",       "Немой",       "Остави",       "Остави") }
    var save:   String { t("Save",   "Запази",      "Тури го",      "Запази го",   "Запази го",    "Запази го") }
    var edit:   String { t("Edit",   "Редактирай",  "Oпеави го",    "Оправи го",   "Оправи го",    "Оправи го") }
    var delete: String { t("Delete", "Изтрий",      "Маaни го",     "Махни го",    "Махни го",     "Махни го") }

    // MARK: Habits List — Empty State
    var emptyHabitsTitle:    String { t("Nothing here yet! 🌱",
                                        "Все още нищо тук! 🌱",
                                        "Па тука нема нищо! 🌱",
                                        "Епа нема нищо туке! 🌱",
                                        "Майна, тука нема нищо! 🌱",
                                        "Ей, батка, нема нищо тука! 🌱") }
    var emptyHabitsSubtitle: String { t("Add your first habit and start your streak 🚀",
                                        "Добави първия си навик 🚀",
                                        "Тури си го тука 🚀",
                                        "Ма тури нещо 🚀",
                                        "Тури си навик бе 🚀",
                                        "Айде тури нещо 🚀") }
    var createFirstHabit:    String { t("Create my first habit",
                                        "Добави навик",
                                        "Тури нещо",
                                        "Тури си нещо",
                                        "Тури навик",
                                        "Тури навик") }

    // MARK: Statistics
    var statsNavTitle:    String { t("Your Progress 🏆",  "Прогресът ти 🏆",              "Колко напреднА 🏆",             "Шо съм направил туке 🏆",  "Прогресът ти 🏆",             "Прогресът ти 🏆") }
    var statsLast30:      String { t("Last 30 Days 🗓️",  "Последните 30 дни 🗓️",         "За 30 дена 🗓️",                "Тия 30 дена 🗓️",           "Последните 30 дена 🗓️",      "Последните 30 дена 🗓️") }
    var statsPerHabit:    String { t("Habit Breakdown",   "По навик",                      "Па я така съм си свикнАл",      "По навик",                  "По навик",                    "По навик") }
    var statsEmptyTitle:  String { t("Nothing to show yet! 🌱",
                                     "Все още нищо тук! 🌱",
                                     "Па тука нема нищо! 🌱",
                                     "Епа нема нищо туке! 🌱",
                                     "Майна, нема кво да покажем! 🌱",
                                     "Ей, нема кво да видим! 🌱") }
    var statsEmptySubtitle: String { t("Track some habits and your stats will appear here ✨",
                                       "Проследявай навици, за да видиш статистиките си ✨",
                                       "Тури навик и седи гледай ✨",
                                       "Ма тури нещо па ше видим ✨",
                                       "Тури навик и ще видиш тука ✨",
                                       "Тури навик и ще видиш тука ✨") }

    // MARK: Add / Edit Habit
    var newHabitTitle:  String { t("New Habit ✨",     "Нов навик ✨",   "Нов навик ✨",          "Нов навик ✨",        "Нов навик ✨",        "Нов навик ✨") }
    var editHabitTitle: String { t("Edit Habit ✏️",   "Редактирай ✏️", "Оправи го тва ✏️",      "Оправи го ✏️",       "Оправи го ✏️",       "Оправи го ✏️") }

    var sectionNameIcon:  String { t("Name & Icon",    "Име и икона",      "Име и картинка",                    "Иметуй и иконката",  "Име и иконка",       "Име и иконка") }
    var sectionColor:     String { t("Accent Color",   "Цвят",             "Боята",                             "Боята",               "Боята",              "Боята") }
    var sectionSchedule:  String { t("Schedule 📅",    "График 📅",        "Кога 📅",                           "Кога 📅",             "Кога 📅",            "Кога 📅") }
    var sectionTracking:  String { t("Tracking 🎯",    "Проследяване 🎯",  "Броене 🎯",                         "Броим 🎯",            "Броене 🎯",          "Броене 🎯") }
    var sectionReminders: String { t("Reminders 🔔",   "Напомняния 🔔",    "Да се сетим, че не помним иначе 🔔","Да те сетим 🔔",      "Напомняния 🔔",      "Напомняния 🔔") }

    var habitNamePlaceholder: String { t("e.g. Morning run, Read 10 pages…",
                                         "напр. Сутрешно бягане, Четене…",
                                         "напр. Сутрешно пиенье...",
                                         "напр. Сабале тичане...",
                                         "напр. Сабале тичане, Четене…",
                                         "напр. Сутрешно тичане, Четене…") }
    var repeatLabel:   String { t("Repeat",        "Повтори",       "Повтори",       "Повтаряй",    "Повтори",       "Повтори") }
    var everyDay:      String { t("Every Day",     "Всеки ден",     "Секи ден",      "Секи ден",    "Секи ден",      "Секи ден") }
    var specificDays:  String { t("Specific Days", "Определени дни","Некои дни",     "Само некои дни","Определени дни","Определени дни") }
    var countItUp:     String { t("Count it up each day",  "Брой всеки път",         "Брой секи път",         "Брой секи пат",         "Брой секи път",         "Брой секи път") }
    var sendReminder:  String { t("Send me a reminder",    "Изпрати напомняне",       "Кажи ми да се пОдсета", "Сети ме",               "Напомни ми бе",         "Сети ме батка") }
    var dailyGoal:     String { t("Daily goal:",   "Дневна цел:",   "Дневна цел:",   "Дневна цел:",   "Дневна цел:",   "Дневна цел:") }
    var timeLabel:     String { t("Time",          "Час",           "Коги",          "У колко",       "Кога",          "Кога") }

    var trackingFooter:  String { t("Tap + each time you do it — you're done when you hit your goal! 🎉",
                                    "Натискай + всеки път. Готово, когато стигнеш целта! 🎉",
                                    "Цъкни + секи пат. Готов си кат наораиш кво треа! 🎉",
                                    "Цъкни + секи пат. Епа кат стигнеш целта – саглам! 🎉",
                                    "Цъкни + секи път. Кат стигнеш целта — убаво бе! 🎉",
                                    "Цъкни + секи път. Кат стигнеш целта — арно де! 🎉") }
    var remindersFooter: String { t("We'll nudge you at this time on your scheduled days 👋",
                                    "Ще ти напомним в това време в насрочените дни 👋",
                                    "Ща пОдсета 👋",
                                    "Ше те сетим 👋",
                                    "Ще ти напомним бе 👋",
                                    "Ще те сетим батка 👋") }

    // MARK: Notifications Alert
    var notifOffTitle:   String { t("Notifications Off 🔕",
                                    "Известията са изключени 🔕",
                                    "Известията са изключени 🔕",
                                    "Нема известия 🔕",
                                    "Известията са изключени 🔕",
                                    "Известията са изключени 🔕") }
    var notifOffMessage: String { t("Head to Settings → PulseDen to turn on notifications.",
                                    "Отиди в Настройки → PulseDen, за да включиш известията.",
                                    "Иди в Наредби → PulseDen да ги пуснеш.",
                                    "Иди у Настройки → PulseDen да ги пуснеш.",
                                    "Иди в Настройки → PulseDen да ги пуснеш бе.",
                                    "Иди в Настройки → PulseDen да ги пуснеш де.") }
    var openSettings:    String { t("Open Settings", "Отвори настройките", "Отвори наредбите", "Отвори настройките", "Отвори настройките", "Отвори настройките") }

    // MARK: History Stats
    var streakLabel: String { t("Streak", "Серия",  "Серия",  "Серия",  "Серия",  "Серия") }
    var bestLabel:   String { t("Best",   "Рекорд", "Рекорд", "Рекорд", "Рекорд", "Рекорд") }
    var todayLabel:  String { t("Today",  "Днес",   "Днеска", "Днеска", "Днеска", "Днеска") }
    var thirtyDays:  String { t("30 Days","30 дни", "30 дена","30 дена","30 дена", "30 дена") }

    // MARK: Emoji Picker
    var pickEmoji:   String { t("Pick Your Vibe 🎉", "Избери емоджи 🎉", "Избери си 🎉",    "Избери си 🎉",    "Избери си 🎉",    "Избери си 🎉") }
    var emojiLabel:  String { t("Emoji",             "Емоджи",           "Иконка",           "Иконката",        "Емоджи",          "Емоджи") }
    var tapToChange: String { t("Tap to change",     "Натисни за смяна", "Цъкни да смениш",  "Цъкни да смениш", "Цъкни да смениш", "Цъкни да смениш") }

    // MARK: Format Strings
    func dayStreak(_ n: Int) -> String { t("\(n) day streak", "серия: \(n) дни", "серия: \(n) дни", "серия: \(n) дни", "серия: \(n) дни", "серия: \(n) дни") }
    func bestStreak(_ n: Int) -> String { t("Best: \(n)", "Рекорд: \(n)", "Рекорд: \(n)", "Рекорд: \(n)", "Рекорд: \(n)", "Рекорд: \(n)") }

    // MARK: New Tabs
    var dashboardTab:  String { t("Home",      "Начало",      "Вкъщи",       "У дома",       "Начало",       "Начало") }
    var remindersTab:  String { t("Reminders", "Напомняния",  "Напомняния",  "Напомняния",   "Напомняния",   "Напомняния") }
    var stuffTab:      String { t("Stuff",     "Неща",        "Работи",      "Работи",       "Неща",         "Работи") }

    // MARK: Dashboard Greetings
    var greetingMorning:   String { t("Good morning! ☀️",      "Добро утро! ☀️",      "Яла, добро утро, баце! ☀️",  "Добро утро! Яз че съм тука! ☀️",  "Майна, добро утро бе! ☀️",       "Добро утро, батка! ☀️") }
    var greetingAfternoon: String { t("Good afternoon! 🌤️",    "Добър ден! 🌤️",       "Е па добър ден! 🌤️",         "Добър ден! Са какво? 🌤️",         "Убав ден бе! 🌤️",               "Добър ден, батка! 🌤️") }
    var greetingEvening:   String { t("Good evening! 🌙",      "Добър вечер! 🌙",     "Арно вече, баце! 🌙",        "Добър вечер! Лека ноч! 🌙",        "Убава вечер бе! 🌙",             "Добър вечер, батка! 🌙") }
    var greetingNight:     String { t("Sweet dreams! 🌜",      "Лека нощ! 🌜",        "Връй пикай, па легай! 🌜",   "Лека ноч! 🌜",                     "Лека нощ бе! 🌜",                "Лека нощ, батка! 🌜") }

    // MARK: Dashboard Cards
    var dashHabitsTitle:    String { t("Habits",     "Навици",     "Навик",      "Навиците",   "Навици",     "Навици") }
    var dashRemindersTitle: String { t("Reminders",  "Напомняния", "Напомняния", "Напомняния", "Напомняния", "Напомняния") }
    var dashStuffTitle:     String { t("Stuff",      "Неща",       "Работи",     "Работи",     "Неща",       "Работи") }

    func dashHabitsDone(_ done: Int, _ total: Int) -> String {
        t("\(done)/\(total) done today",
          "\(done)/\(total) за днес",
          "\(done)/\(total) за днеска",
          "\(done)/\(total) за днеска",
          "\(done)/\(total) за днеска",
          "\(done)/\(total) за днеска")
    }

    var dashBestStreak:  String { t("Best streak",  "Най-добра серия",  "Най-добра серия",  "Рекорд серия",  "Най-убава серия",  "Най-добра серия") }

    func dashUpcoming(_ n: Int) -> String {
        t("\(n) upcoming", "\(n) предстоящи", "\(n) предстоящи", "\(n) предстоящи", "\(n) предстоящи", "\(n) предстоящи")
    }
    func dashOverdue(_ n: Int) -> String {
        t("\(n) overdue", "\(n) закъснели", "\(n) закъснели", "\(n) закъснели", "\(n) закъснели", "\(n) закъснели")
    }
    var dashNextReminder: String { t("Next:", "Следващо:", "Следващо:", "Следващо:", "Следващо:", "Следващо:") }

    func dashStuffCount(_ n: Int) -> String {
        t("\(n) items", "\(n) неща", "\(n) работи", "\(n) работи", "\(n) неща", "\(n) работи")
    }
    var dashRecentlyAdded: String { t("Recently added", "Последно добавени", "Скоро турнати", "Скоро турени", "Скоро добавени", "Скоро добавени") }

    var dashNoHabitsYet:    String { t("No habits yet",    "Все още нямаш навици",    "Нема навик още",        "Нема навици още",       "Нема навици още бе",      "Нема навици още батка") }
    var dashNoRemindersYet: String { t("No reminders yet", "Все още нямаш напомняния","Нема напомняния още",   "Нема напомняния още",   "Нема напомняния още",     "Нема напомняния още") }
    var dashNoStuffYet:     String { t("No stuff saved yet","Все още нямаш неща",     "Нема нищо турнато още", "Нема нищо турено още",  "Нема нищо още бе",        "Нема нищо още батка") }

    // MARK: Reminders
    var newReminderTitle:  String { t("New Reminder ⏰",  "Ново напомняне ⏰",  "Ново напомняне ⏰",  "Ново напомняне ⏰",  "Ново напомняне ⏰",  "Ново напомняне ⏰") }
    var editReminderTitle: String { t("Edit Reminder ✏️", "Редактирай ✏️",      "Оправи го ✏️",       "Оправи го ✏️",       "Оправи го ✏️",       "Оправи го ✏️") }

    var reminderNamePlaceholder: String { t("e.g. Pick up kids, Water plants…",
                                             "напр. Вземи децата, Полей цветята…",
                                             "напр. Вземи дечурлигата, Полей цветята…",
                                             "напр. Прибери децата, Полей цветята…",
                                             "напр. Вземи децата, Полей цветята…",
                                             "напр. Вземи децата, Полей цветята…") }
    var reminderNotePlaceholder: String { t("Add a note (optional)",
                                             "Бележка (по желание)",
                                             "Белешка (ако сакаш)",
                                             "Белешка (ако сакаш)",
                                             "Бележка (ако искаш)",
                                             "Бележка (ако искаш)") }
    var reminderSectionWhen:   String { t("When ⏰",    "Кога ⏰",    "Кога ⏰",    "Кога ⏰",    "Кога ⏰",    "Кога ⏰") }
    var reminderSectionRepeat: String { t("Repeat 🔁",  "Повтаряне 🔁","Повтаряне 🔁","Повтаряне 🔁","Повтаряне 🔁","Повтаряне 🔁") }

    var reminderOnce:    String { t("Once",    "Веднъж",    "Веднъж",    "Еднъж",    "Веднъж",    "Веднъж") }
    var reminderDaily:   String { t("Daily",   "Всеки ден", "Секи ден",  "Секи ден", "Секи ден",  "Секи ден") }
    var reminderWeekly:  String { t("Weekly",  "Седмично",  "На седмица","На седмица","На седмица","На седмица") }
    var reminderMonthly: String { t("Monthly", "Месечно",   "На месец",  "На месец", "На месец",  "На месец") }

    var reminderDayOfMonth: String { t("Day of month", "Ден от месеца", "Ден от месеца", "Ден от месеца", "Ден от месеца", "Ден от месеца") }

    var reminderMarkComplete: String { t("Complete", "Готово", "Готово", "Арно", "Готово бе", "Арно де") }

    var remindersOverdue:   String { t("Overdue 🔴",   "Закъснели 🔴",   "Закъснели 🔴",   "Закъснели 🔴",   "Закъснели 🔴",   "Закъснели 🔴") }
    var remindersUpcoming:  String { t("Upcoming 🔵",  "Предстоящи 🔵",  "Предстоящи 🔵",  "Предстоящи 🔵",  "Предстоящи 🔵",  "Предстоящи 🔵") }
    var remindersCompleted: String { t("Completed ✅", "Изпълнени ✅",    "Готовите ✅",      "Станалите ✅",    "Готовите ✅",      "Готовите ✅") }

    var emptyRemindersTitle:    String { t("No reminders yet! 🔔",
                                            "Все още нямаш напомняния! 🔔",
                                            "Па тука нема нищо! 🔔",
                                            "Епа нема напомняния туке! 🔔",
                                            "Майна, нема напомняния! 🔔",
                                            "Ей, нема напомняния! 🔔") }
    var emptyRemindersSubtitle: String { t("Add a reminder so you never forget 🧠",
                                            "Добави напомняне за да не забравиш 🧠",
                                            "Тури нещо да не забраиш 🧠",
                                            "Тури нещо да не забраиш 🧠",
                                            "Тури нещо да не забравиш бе 🧠",
                                            "Тури нещо да не забравиш 🧠") }
    var createFirstReminder:    String { t("Create my first reminder",
                                            "Създай първото напомняне",
                                            "Тури нещо",
                                            "Тури нещо",
                                            "Тури напомняне",
                                            "Тури напомняне") }

    // MARK: Stuff
    var newStuffTitle:  String { t("New Item 📌",  "Ново нещо 📌",  "Нова работа 📌",  "Нова работа 📌",  "Ново нещо 📌",  "Нова работа 📌") }
    var editStuffTitle: String { t("Edit Item ✏️", "Редактирай ✏️", "Оправи го ✏️",     "Оправи го ✏️",     "Оправи го ✏️",   "Оправи го ✏️") }

    var stuffNamePlaceholder: String { t("e.g. Grandma's recipe, Cool article…",
                                          "напр. Рецепта на баба, Готина статия…",
                                          "напр. Рецепта на баба, Готина статия…",
                                          "напр. Рецепта на баба, Арна статия…",
                                          "напр. Рецепта на баба, Убава статия…",
                                          "напр. Рецепта на баба, Арна статия…") }
    var stuffNotePlaceholder: String { t("Add details (optional)",
                                          "Детайли (по желание)",
                                          "Детайли (ако сакаш)",
                                          "Детайли (ако сакаш)",
                                          "Детайли (ако искаш)",
                                          "Детайли (ако искаш)") }

    var stuffSectionDetails:  String { t("Details 📝",  "Детайли 📝",   "Детайли 📝",   "Детайли 📝",   "Детайли 📝",   "Детайли 📝") }
    var stuffSectionCategory: String { t("Category 🏷️", "Категория 🏷️", "Категория 🏷️", "Категория 🏷️", "Категория 🏷️", "Категория 🏷️") }
    var stuffSectionRating:   String { t("Rating ⭐",    "Оценка ⭐",     "Оценка ⭐",     "Оценка ⭐",     "Оценка ⭐",     "Оценка ⭐") }
    var stuffSectionPhoto:    String { t("Photo 📷",     "Снимка 📷",    "Снимка 📷",    "Снимка 📷",    "Снимка 📷",    "Снимка 📷") }

    var stuffAddPhoto:    String { t("Add photo",     "Добави снимка",  "Тури снимка",   "Тури снимка",   "Тури снимка",   "Тури снимка") }
    var stuffChangePhoto: String { t("Change photo",  "Смени снимката", "Смени снимката","Смени снимката","Смени снимката","Смени снимката") }
    var stuffRemovePhoto: String { t("Remove photo",  "Махни снимката", "Махни снимката","Махни снимката","Махни снимката","Махни снимката") }

    var stuffArchive:      String { t("Archive",       "Архивирай",     "Архивирай",     "Архивирай",     "Архивирай",     "Архивирай") }
    var stuffUnarchive:    String { t("Unarchive",     "Извади",        "Извади",        "Извади",        "Извади",        "Извади") }
    var stuffShowArchived: String { t("Show Archived", "Покажи архива", "Покажи архива", "Покажи архива", "Покажи архива", "Покажи архива") }
    var stuffHideArchived: String { t("Hide Archived", "Скрий архива",  "Скрий архива",  "Скрий архива",  "Скрий архива",  "Скрий архива") }

    var sortByRating:   String { t("By Rating",   "По оценка",    "По оценка",    "По оценка",    "По оценка",    "По оценка") }
    var sortByDate:     String { t("By Date",     "По дата",      "По дата",      "По дата",      "По дата",      "По дата") }
    var sortByCategory: String { t("By Category", "По категория", "По категория", "По категория", "По категория", "По категория") }

    var emptyStuffTitle:    String { t("Nothing saved yet! 📌",
                                        "Все още нямаш неща! 📌",
                                        "Па тука нема нищо! 📌",
                                        "Епа нема нищо туке! 📌",
                                        "Майна, нема нищо тука! 📌",
                                        "Ей, нема нищо тука! 📌") }
    var emptyStuffSubtitle: String { t("Save recipes, articles, ideas — anything worth keeping 💡",
                                        "Запази рецепти, статии, идеи — всичко важно 💡",
                                        "Тури рецепти, статии, идеи — шо ти треа 💡",
                                        "Тури рецепти, статии, идеи — шо ти треа 💡",
                                        "Тури рецепти, статии, идеи — кво ти трябва 💡",
                                        "Тури рецепти, статии, идеи — кво ти трябва 💡") }
    var createFirstStuff:   String { t("Save my first thing",
                                        "Запази първото нещо",
                                        "Тури нещо",
                                        "Тури нещо",
                                        "Запази нещо",
                                        "Тури нещо") }

    // MARK: Shared
    var note:     String { t("Note",     "Бележка",    "Белешка",    "Белешка",    "Бележка",    "Бележка") }
    var archive:  String { t("Archive",  "Архивирай",  "Архивирай",  "Архивирай",  "Архивирай",  "Архивирай") }
    var complete: String { t("Complete", "Готово",     "Готово",     "Арно",       "Готово бе",   "Арно де") }

    // MARK: Chat / AI
    var chatTab:         String { aiName }
    var chatTitle:       String { "\(aiName) 🐾" }
    var chatPlaceholder: String { t("Ask \(aiName) anything…", "Питай \(aiName) нещо…", "Питай \(aiName) нещо…", "Питай \(aiName) нещо…", "Питай \(aiName) нещо бе…", "Питай \(aiName) нещо батка…") }
    var chatWelcome:     String { t("Hey! I'm \(aiName) — your PulseDen sidekick! I know your habits, reminders, stocks, health & more. Ask me anything! 🐾",
                                     "Здрасти! Аз съм \(aiName) — твоят верен помощник в PulseDen! Знам за навиците, напомнянията, акциите и здравето ти. Питай ме! 🐾",
                                     "Яла, баце! Язе сам \(aiName) — твоя помощник в PulseDen! Знам за навиците, напомнянията, акциите и здравето ти. Питай ме! 🐾",
                                     "Яз съм \(aiName) — твоя помощник у PulseDen! Знам за навиците, напомнянията, акциите и здравето ти. Питай ме! 🐾",
                                     "Майна! Аз съм \(aiName) — твоят помощник в PulseDen! Знам за навиците, напомнянията, акциите и здравето ти. Питай ме бе! 🐾",
                                     "Ей, батка! Аз съм \(aiName) — твоят помощник в PulseDen! Знам за навиците, напомнянията, акциите и здравето ти. Питай ме! 🐾") }
    var chatSend:        String { t("Send",               "Изпрати",           "Изпрати",           "Изпрати",           "Изпрати",           "Изпрати") }
    var chatNoApiKey:    String { t("Set your Claude API key in Settings to wake up \(aiName)",
                                     "Добави Claude API ключ в Настройки за да събудиш \(aiName)",
                                     "Тури Claude API ключ в Наредбите за да събудиш \(aiName)",
                                     "Тури Claude API ключ у Настройки за да събудиш \(aiName)",
                                     "Тури Claude API ключ в Настройки за да събудиш \(aiName) бе",
                                     "Тури Claude API ключ в Настройки за да събудиш \(aiName) батка") }
    var chatApiKeyTitle: String { t("Claude API Key",     "Claude API Ключ",   "Claude API Ключ",   "Claude API Ключ",   "Claude API Ключ",   "Claude API Ключ") }
    var chatApiKeyPlaceholder: String { t("sk-ant-…",     "sk-ant-…",          "sk-ant-…",          "sk-ant-…",          "sk-ant-…",          "sk-ant-…") }
    var chatApiKeyFooter: String { t("Get your key from console.anthropic.com",
                                      "Вземи ключа от console.anthropic.com",
                                      "Вземи ключа от console.anthropic.com",
                                      "Вземи ключа от console.anthropic.com",
                                      "Вземи ключа от console.anthropic.com",
                                      "Вземи ключа от console.anthropic.com") }
    var dashAiTitle:     String { aiName }
    var aiNameLabel:     String { t("Assistant Name",     "Име на асистента",  "Име на помощника",  "Име на помощника",  "Име на помощника",  "Име на помощника") }
    var autoSpeakLabel:  String { t("Read Responses Aloud", "Четене на отговорите на глас", "Четене на отговорите на глас", "Четене на отговорите на глас", "Четене на отговорите на глас", "Четене на отговорите на глас") }
    var modulesLabel:    String { t("Modules",             "Модули",              "Модули",              "Модули",              "Модули",              "Модули") }

    // MARK: Health
    var healthTab:       String { t("Health",              "Здраве",              "Здравето",            "Здравето",            "Здравето",            "Здравето") }
    var healthTitle:     String { t("Health 🏥",           "Здраве 🏥",           "Здравето 🏥",         "Здравето 🏥",         "Здравето 🏥",         "Здравето 🏥") }
    var healthSleep:     String { t("Sleep",               "Сън",                 "Сън",                 "Сън",                 "Сън",                 "Сън") }
    var healthHeartRate: String { t("Heart Rate",          "Пулс",                "Пулс",                "Пулс",                "Пулс",                "Пулс") }
    var healthSteps:     String { t("Steps",               "Стъпки",              "Стъпки",              "Стъпки",              "Стъпки",              "Стъпки") }
    var healthCalories:  String { t("Active Calories",     "Активни калории",     "Активни калории",     "Активни калории",     "Активни калории",     "Активни калории") }
    var healthConnect:   String { t("Connect Apple Health","Свържи Apple Health", "Свържи Apple Health", "Свържи Apple Health", "Свържи Apple Health", "Свържи Apple Health") }
    var healthConnectSubtitle: String { t("See your sleep, heart rate, steps and activity right here",
                                           "Виж съня, пулса, стъпките и активността си тук",
                                           "Виж съня, пулса и стъпките тука",
                                           "Виж съня, пулса и стъпките туке",
                                           "Виж съня, пулса и стъпките тука бе",
                                           "Виж съня, пулса и стъпките тука батка") }
    var healthRetry:     String { t("Try Again",           "Опитай пак",          "Пак пробвай",         "Пак пробвай",         "Пак пробвай бе",      "Пак пробвай де") }
    var healthLastNight: String { t("Last night",          "Снощи",               "Снощи",               "Снощи",               "Снощи",               "Снощи") }
    var healthRestingHR: String { t("Resting",             "В покой",             "В покой",             "В покой",             "В покой",             "В покой") }
    var dashHealthTitle: String { t("Health",              "Здраве",              "Здравето",            "Здравето",            "Здравето",            "Здравето") }

    // MARK: Stocks
    var stocksTab:            String { t("Stocks",               "Акции",               "Акции",               "Акции",               "Акции",               "Акции") }
    var stocksTitle:          String { t("Stocks 📈",            "Акции 📈",            "Акции 📈",            "Акции 📈",            "Акции 📈",            "Акции 📈") }
    var stocksAdd:            String { t("Add",                  "Добави",              "Тури",                "Тури",                "Тури",                "Тури") }
    var stocksAddPlaceholder: String { t("Symbol (e.g. AAPL)",   "Символ (напр. AAPL)", "Символ (напр. AAPL)", "Символ (напр. AAPL)", "Символ (напр. AAPL)", "Символ (напр. AAPL)") }
    var stocksSearchPlaceholder: String { t("Search stocks or enter symbol", "Търси акции или символ", "Тражи акции или символ", "Тражи акции или символ", "Търси акции или символ", "Търси акции или символ") }
    var stocksEmpty:          String { t("Add stocks to track",  "Добави акции",        "Тури акции",          "Тури акции",          "Тури акции бе",        "Тури акции батка") }
    var stocksRemove:         String { t("Remove",               "Премахни",            "Махни",               "Махни",               "Махни",               "Махни") }
    var stocksTopMovers:      String { t("Top Movers",           "Най-големи промени",  "Най-големи промени",  "Най-големи промени",  "Най-големи промени",  "Най-големи промени") }
    var dashStocksTitle:      String { t("Stocks",               "Акции",               "Акции",               "Акции",               "Акции",               "Акции") }
    func stocksTracked(_ n: Int) -> String { t("\(n) stocks tracked", "\(n) акции", "\(n) акции", "\(n) акции", "\(n) акции", "\(n) акции") }

    // MARK: News
    var newsTab:               String { t("News",                         "Новини",                        "Новини",                        "Новини",                        "Новини",                        "Новини") }
    var newsTitle:             String { t("News 📰",                     "Новини 📰",                     "Новини 📰",                     "Новини 📰",                     "Новини 📰",                     "Новини 📰") }
    var newsWorldTitle:        String { t("World News",                   "Световни новини",               "Световни новини",               "Световни новини",               "Световни новини",               "Световни новини") }
    var newsBulgarianTitle:    String { t("Bulgarian News",               "Български новини",              "Български новини",              "Български новини",              "Български новини",              "Български новини") }
    var newsEmpty:             String { t("Add your GNews API key in Settings to see daily news", "Добави GNews API ключ в Настройки", "Тури GNews API ключ в Настройки", "Тури GNews API ключ в Настройки", "Тури GNews API ключ в Настройки бе", "Тури GNews API ключ в Настройки батка") }
    var newsNoArticles:        String { t("No articles found",            "Няма намерени статии",          "Нема статии",                   "Нема статии",                   "Нема статии бе",                "Нема статии батка") }
    var dashNewsTitle:         String { t("News",                         "Новини",                        "Новини",                        "Новини",                        "Новини",                        "Новини") }
    var newsApiKeyTitle:       String { t("GNews API Key",                "GNews API ключ",                "GNews API ключ",                "GNews API ключ",                "GNews API ключ",                "GNews API ключ") }
    var newsApiKeyPlaceholder: String { t("Enter your GNews API key",    "Въведи GNews API ключ",         "Тури GNews API ключ",           "Тури GNews API ключ",           "Тури GNews API ключ",           "Тури GNews API ключ") }
    var newsApiKeyFooter:      String { t("Get a free key at gnews.io",  "Вземи безплатен ключ от gnews.io", "Вземи ключ от gnews.io",    "Вземи ключ от gnews.io",        "Вземи ключ от gnews.io",        "Вземи ключ от gnews.io") }

    // MARK: Weather
    var weatherTab:          String { t("Weather",              "Времето",              "Времето",              "Времето",              "Времето",              "Времето") }
    var weatherLoading:      String { t("Loading weather…",     "Зарежда времето…",     "Зарежда се…",          "Зарежда се…",          "Зарежда се бе…",       "Зарежда се…") }
    var weatherRetry:        String { t("Try Again",            "Опитай пак",           "Пак пробвай",          "Пак пробвай",          "Пак пробвай бе",       "Пак пробвай де") }
    var weatherErrorTitle:   String { t("Couldn't Load Weather","Грешка при зареждане", "Нема времето",         "Нема времето",         "Пусто, нема времето",   "Нема времето батка") }
    var weatherCheckLocation: String { t("Fetching your location…", "Намираме те…",     "Де си…",               "Де си бе…",            "Де си бе…",            "Де си батка…") }
    var weatherHourly:       String { t("Hourly Forecast",      "По часове",            "По час",               "По час",               "По час",               "По час") }
    var weatherDaily:        String { t("7-Day Forecast",       "7 дни напред",         "7 дена напред",        "7 дена напред",        "7 дена напред",        "7 дена напред") }
    var weatherFeelsLike:    String { t("Feels Like",           "Усеща се",             "Усеща се",             "Усеща се",             "Усеща се",             "Усеща се") }
    var weatherHumidity:     String { t("Humidity",             "Влажност",             "Влажност",             "Влажност",             "Влажност",             "Влажност") }
    var weatherWind:         String { t("Wind",                 "Вятър",                "Вятър",                "Вятър",                "Вятър",                "Вятър") }
    var weatherDayNight:     String { t("Time of Day",          "Ден/Нощ",              "Ден/Нощ",              "Ден/Нощ",              "Ден/Нощ",              "Ден/Нощ") }
    var weatherDay:          String { t("Day",                  "Ден",                  "Ден",                  "Ден",                  "Ден",                  "Ден") }
    var weatherNight:        String { t("Night",                "Нощ",                  "Нощ",                  "Нощ",                  "Нощ",                  "Нощ") }
    var weatherToday:        String { t("Today",                "Днес",                 "Днеска",               "Днеска",               "Днеска",               "Днеска") }
    var dashWeatherTitle:    String { t("Weather",              "Времето",              "Времето",              "Времето",              "Времето",              "Времето") }
    var dashWeatherTap:      String { t("Tap to see forecast",  "Виж прогнозата",       "Виж прогнозата",       "Виж прогнозата",       "Виж прогнозата бе",    "Виж прогнозата батка") }
}
