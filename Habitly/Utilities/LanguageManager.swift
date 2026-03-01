import Foundation
import Observation

// MARK: - App Language

enum AppLanguage: String, CaseIterable {
    case english      = "en"
    case bulgarian    = "bg"
    case northwestern = "nw"   // Northwestern Bulgarian dialect (Враца / Монтана) 🌾
    case shopluk      = "sh"   // Pernishko dialect (Перник / Земен) ⚒️

    var displayName: String {
        switch self {
        case .english:      return "English"
        case .bulgarian:    return "Български"
        case .northwestern: return "Северо-Запад 🌾"
        case .shopluk:      return "Пернишко ⚒️"
        }
    }
}

// MARK: - Language Manager

@MainActor @Observable final class LanguageManager {
    static let shared = LanguageManager()

    var current: AppLanguage {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: "appLanguage") }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        self.current = AppLanguage(rawValue: saved) ?? .english
    }

    /// Pick the right string for the current language.
    func t(_ en: String, _ bg: String, _ nw: String, _ sh: String) -> String {
        switch current {
        case .english:      return en
        case .bulgarian:    return bg
        case .northwestern: return nw
        case .shopluk:      return sh
        }
    }
}

// MARK: - All Translated Strings

extension LanguageManager {

    // MARK: Tabs & Nav
    var habitsTab:    String { t("Habits",   "Навици",     "Навик",      "Навиките") }
    var progressTab:  String { t("Progress", "Прогрес",    "Напредък",   "Шо съм постигнал") }
    var settings:     String { t("Settings", "Настройки",  "Наредби",    "Настройки") }
    var language:     String { t("Language", "Език",       "Език",       "Жезика") }

    // MARK: Common Actions
    var done:   String { t("Done",   "Готово",      "Готово бе!",   "Арно!") }
    var cancel: String { t("Cancel", "Отказ",       "Остави",       "Немой") }
    var save:   String { t("Save",   "Запази",      "Тури го",      "Запази го") }
    var edit:   String { t("Edit",   "Редактирай",  "Oпеави го",    "Оправи го") }
    var delete: String { t("Delete", "Изтрий",      "Маaни го",     "Махни го") }

    // MARK: Habits List — Empty State
    var emptyHabitsTitle:    String { t("Nothing here yet! 🌱",
                                        "Все още нищо тук! 🌱",
                                        "Па тука нема нищо! 🌱",
                                        "Епа нема нищо туке! 🌱") }
    var emptyHabitsSubtitle: String { t("Add your first habit and start your streak 🚀",
                                        "Добави първия си навик 🚀",
                                        "Тури си го тука 🚀",
                                        "Ма тури нещо 🚀") }
    var createFirstHabit:    String { t("Create my first habit",
                                        "Добави навик",
                                        "Тури нещо",
                                        "Тури си нещо") }

    // MARK: Statistics
    var statsNavTitle:    String { t("Your Progress 🏆",  "Прогресът ти 🏆",              "Колко напреднА 🏆",             "Шо съм направил туке 🏆") }
    var statsLast30:      String { t("Last 30 Days 🗓️",  "Последните 30 дни 🗓️",         "За 30 дена 🗓️",                "Тия 30 дена 🗓️") }
    var statsPerHabit:    String { t("Habit Breakdown",   "По навик",                      "Па я така съм си свикнАл",      "По навик") }
    var statsEmptyTitle:  String { t("Nothing to show yet! 🌱",
                                     "Все още нищо тук! 🌱",
                                     "Па тука нема нищо! 🌱",
                                     "Епа нема нищо туке! 🌱") }
    var statsEmptySubtitle: String { t("Track some habits and your stats will appear here ✨",
                                       "Проследявай навици, за да видиш статистиките си ✨",
                                       "Тури навик и седи гледай ✨",
                                       "Ма тури нещо па ше видим ✨") }

    // MARK: Add / Edit Habit
    var newHabitTitle:  String { t("New Habit ✨",     "Нов навик ✨",   "Нов навик ✨",          "Нов навик ✨") }
    var editHabitTitle: String { t("Edit Habit ✏️",   "Редактирай ✏️", "Оправи го тва ✏️",      "Оправи го ✏️") }

    var sectionNameIcon:  String { t("Name & Icon",    "Име и икона",      "Име и картинка",                    "Иметуй и иконката") }
    var sectionColor:     String { t("Accent Color",   "Цвят",             "Боята",                             "Боята") }
    var sectionSchedule:  String { t("Schedule 📅",    "График 📅",        "Кога 📅",                           "Кога 📅") }
    var sectionTracking:  String { t("Tracking 🎯",    "Проследяване 🎯",  "Броене 🎯",                         "Броим 🎯") }
    var sectionReminders: String { t("Reminders 🔔",   "Напомняния 🔔",    "Да се сетим, че не помним иначе 🔔","Да те сетим 🔔") }

    var habitNamePlaceholder: String { t("e.g. Morning run, Read 10 pages…",
                                         "напр. Сутрешно бягане, Четене…",
                                         "напр. Сутрешно пиенье...",
                                         "напр. Сабале тичане...") }
    var repeatLabel:   String { t("Repeat",        "Повтори",       "Повтори",       "Повтаряй") }
    var everyDay:      String { t("Every Day",     "Всеки ден",     "Секи ден",      "Секи ден") }
    var specificDays:  String { t("Specific Days", "Определени дни","Некои дни",     "Само некои дни") }
    var countItUp:     String { t("Count it up each day",  "Брой всеки път",         "Брой секи път",         "Брой секи пат") }
    var sendReminder:  String { t("Send me a reminder",    "Изпрати напомняне",       "Кажи ми да се пОдсета", "Сети ме") }
    var dailyGoal:     String { t("Daily goal:",   "Дневна цел:",   "Дневна цел:",   "Дневна цел:") }
    var timeLabel:     String { t("Time",          "Час",           "Коги",          "У колко") }

    var trackingFooter:  String { t("Tap + each time you do it — you're done when you hit your goal! 🎉",
                                    "Натискай + всеки път. Готово, когато стигнеш целта! 🎉",
                                    "Цъкни + секи пат. Готов си кат наораиш кво треа! 🎉",
                                    "Цъкни + секи пат. Епа кат стигнеш целта – саглам! 🎉") }
    var remindersFooter: String { t("We'll nudge you at this time on your scheduled days 👋",
                                    "Ще ти напомним в това време в насрочените дни 👋",
                                    "Ща пОдсета 👋",
                                    "Ше те сетим 👋") }

    // MARK: Notifications Alert
    var notifOffTitle:   String { t("Notifications Off 🔕",
                                    "Известията са изключени 🔕",
                                    "Известията са изключени 🔕",
                                    "Нема известия 🔕") }
    var notifOffMessage: String { t("Head to Settings → Habitly to turn on notifications.",
                                    "Отиди в Настройки → Habitly, за да включиш известията.",
                                    "Иди в Наредби → Habitly да ги пуснеш.",
                                    "Иди у Настройки → Habitly да ги пуснеш.") }
    var openSettings:    String { t("Open Settings", "Отвори настройките", "Отвори наредбите", "Отвори настройките") }

    // MARK: History Stats
    var streakLabel: String { t("Streak", "Серия",  "Серия",  "Серия") }
    var bestLabel:   String { t("Best",   "Рекорд", "Рекорд", "Рекорд") }
    var todayLabel:  String { t("Today",  "Днес",   "Днеска", "Днеска") }
    var thirtyDays:  String { t("30 Days","30 дни", "30 дена","30 дена") }

    // MARK: Emoji Picker
    var pickEmoji:   String { t("Pick Your Vibe 🎉", "Избери емоджи 🎉", "Избери си 🎉",    "Избери си 🎉") }
    var emojiLabel:  String { t("Emoji",             "Емоджи",           "Иконка",           "Иконката") }
    var tapToChange: String { t("Tap to change",     "Натисни за смяна", "Цъкни да смениш",  "Цъкни да смениш") }

    // MARK: Format Strings
    func dayStreak(_ n: Int) -> String { t("\(n) day streak", "серия: \(n) дни", "серия: \(n) дни", "серия: \(n) дни") }
    func bestStreak(_ n: Int) -> String { t("Best: \(n)", "Рекорд: \(n)", "Рекорд: \(n)", "Рекорд: \(n)") }

    // MARK: New Tabs
    var dashboardTab:  String { t("Home",      "Начало",      "Вкъщи",       "У дома") }
    var remindersTab:  String { t("Reminders", "Напомняния",  "Напомняния",  "Напомняния") }
    var stuffTab:      String { t("Stuff",     "Неща",        "Работи",      "Работи") }

    // MARK: Dashboard Greetings
    var greetingMorning:   String { t("Good morning! ☀️",      "Добро утро! ☀️",      "Добро утро! ☀️",      "Епа добро утро! ☀️") }
    var greetingAfternoon: String { t("Good afternoon! 🌤️",    "Добър ден! 🌤️",       "Добър ден! 🌤️",       "Епа добър ден! 🌤️") }
    var greetingEvening:   String { t("Good evening! 🌙",      "Добър вечер! 🌙",     "Добър вечер! 🌙",     "Арно вече! 🌙") }
    var greetingNight:     String { t("Sweet dreams! 🌜",      "Лека нощ! 🌜",        "Лека нощ! 🌜",        "Лека нощ! 🌜") }

    // MARK: Dashboard Cards
    var dashHabitsTitle:    String { t("Habits",     "Навици",     "Навик",      "Навиците") }
    var dashRemindersTitle: String { t("Reminders",  "Напомняния", "Напомняния", "Напомняния") }
    var dashStuffTitle:     String { t("Stuff",      "Неща",       "Работи",     "Работи") }

    func dashHabitsDone(_ done: Int, _ total: Int) -> String {
        t("\(done)/\(total) done today",
          "\(done)/\(total) за днес",
          "\(done)/\(total) за днеска",
          "\(done)/\(total) за днеска")
    }

    var dashBestStreak:  String { t("Best streak",  "Най-добра серия",  "Най-добра серия",  "Рекорд серия") }

    func dashUpcoming(_ n: Int) -> String {
        t("\(n) upcoming", "\(n) предстоящи", "\(n) предстоящи", "\(n) предстоящи")
    }
    func dashOverdue(_ n: Int) -> String {
        t("\(n) overdue", "\(n) закъснели", "\(n) закъснели", "\(n) закъснели")
    }
    var dashNextReminder: String { t("Next:", "Следващо:", "Следващо:", "Следващо:") }

    func dashStuffCount(_ n: Int) -> String {
        t("\(n) items", "\(n) неща", "\(n) работи", "\(n) работи")
    }
    var dashRecentlyAdded: String { t("Recently added", "Последно добавени", "Скоро турнати", "Скоро турени") }

    var dashNoHabitsYet:    String { t("No habits yet",    "Все още нямаш навици",    "Нема навик още",        "Нема навици още") }
    var dashNoRemindersYet: String { t("No reminders yet", "Все още нямаш напомняния","Нема напомняния още",   "Нема напомняния още") }
    var dashNoStuffYet:     String { t("No stuff saved yet","Все още нямаш неща",     "Нема нищо турнато още", "Нема нищо турено още") }

    // MARK: Reminders
    var newReminderTitle:  String { t("New Reminder ⏰",  "Ново напомняне ⏰",  "Ново напомняне ⏰",  "Ново напомняне ⏰") }
    var editReminderTitle: String { t("Edit Reminder ✏️", "Редактирай ✏️",      "Оправи го ✏️",       "Оправи го ✏️") }

    var reminderNamePlaceholder: String { t("e.g. Pick up kids, Water plants…",
                                             "напр. Вземи децата, Полей цветята…",
                                             "напр. Вземи дечурлигата, Полей цветята…",
                                             "напр. Прибери децата, Полей цветята…") }
    var reminderNotePlaceholder: String { t("Add a note (optional)",
                                             "Бележка (по желание)",
                                             "Белешка (ако сакаш)",
                                             "Белешка (ако сакаш)") }
    var reminderSectionWhen:   String { t("When ⏰",    "Кога ⏰",    "Кога ⏰",    "Кога ⏰") }
    var reminderSectionRepeat: String { t("Repeat 🔁",  "Повтаряне 🔁","Повтаряне 🔁","Повтаряне 🔁") }

    var reminderOnce:    String { t("Once",    "Веднъж",    "Веднъж",    "Еднъж") }
    var reminderDaily:   String { t("Daily",   "Всеки ден", "Секи ден",  "Секи ден") }
    var reminderWeekly:  String { t("Weekly",  "Седмично",  "На седмица","На седмица") }
    var reminderMonthly: String { t("Monthly", "Месечно",   "На месец",  "На месец") }

    var reminderDayOfMonth: String { t("Day of month", "Ден от месеца", "Ден от месеца", "Ден от месеца") }

    var reminderMarkComplete: String { t("Complete", "Готово", "Готово", "Арно") }

    var remindersOverdue:   String { t("Overdue 🔴",   "Закъснели 🔴",   "Закъснели 🔴",   "Закъснели 🔴") }
    var remindersUpcoming:  String { t("Upcoming 🔵",  "Предстоящи 🔵",  "Предстоящи 🔵",  "Предстоящи 🔵") }
    var remindersCompleted: String { t("Completed ✅", "Изпълнени ✅",    "Готовите ✅",      "Станалите ✅") }

    var emptyRemindersTitle:    String { t("No reminders yet! 🔔",
                                            "Все още нямаш напомняния! 🔔",
                                            "Па тука нема нищо! 🔔",
                                            "Епа нема напомняния туке! 🔔") }
    var emptyRemindersSubtitle: String { t("Add a reminder so you never forget 🧠",
                                            "Добави напомняне за да не забравиш 🧠",
                                            "Тури нещо да не забраиш 🧠",
                                            "Тури нещо да не забраиш 🧠") }
    var createFirstReminder:    String { t("Create my first reminder",
                                            "Създай първото напомняне",
                                            "Тури нещо",
                                            "Тури нещо") }

    // MARK: Stuff
    var newStuffTitle:  String { t("New Item 📌",  "Ново нещо 📌",  "Нова работа 📌",  "Нова работа 📌") }
    var editStuffTitle: String { t("Edit Item ✏️", "Редактирай ✏️", "Оправи го ✏️",     "Оправи го ✏️") }

    var stuffNamePlaceholder: String { t("e.g. Grandma's recipe, Cool article…",
                                          "напр. Рецепта на баба, Готина статия…",
                                          "напр. Рецепта на баба, Готина статия…",
                                          "напр. Рецепта на баба, Арна статия…") }
    var stuffNotePlaceholder: String { t("Add details (optional)",
                                          "Детайли (по желание)",
                                          "Детайли (ако сакаш)",
                                          "Детайли (ако сакаш)") }

    var stuffSectionDetails:  String { t("Details 📝",  "Детайли 📝",   "Детайли 📝",   "Детайли 📝") }
    var stuffSectionCategory: String { t("Category 🏷️", "Категория 🏷️", "Категория 🏷️", "Категория 🏷️") }
    var stuffSectionRating:   String { t("Rating ⭐",    "Оценка ⭐",     "Оценка ⭐",     "Оценка ⭐") }
    var stuffSectionPhoto:    String { t("Photo 📷",     "Снимка 📷",    "Снимка 📷",    "Снимка 📷") }

    var stuffAddPhoto:    String { t("Add photo",     "Добави снимка",  "Тури снимка",   "Тури снимка") }
    var stuffChangePhoto: String { t("Change photo",  "Смени снимката", "Смени снимката","Смени снимката") }
    var stuffRemovePhoto: String { t("Remove photo",  "Махни снимката", "Махни снимката","Махни снимката") }

    var stuffArchive:      String { t("Archive",       "Архивирай",     "Архивирай",     "Архивирай") }
    var stuffUnarchive:    String { t("Unarchive",     "Извади",        "Извади",        "Извади") }
    var stuffShowArchived: String { t("Show Archived", "Покажи архива", "Покажи архива", "Покажи архива") }
    var stuffHideArchived: String { t("Hide Archived", "Скрий архива",  "Скрий архива",  "Скрий архива") }

    var sortByRating:   String { t("By Rating",   "По оценка",    "По оценка",    "По оценка") }
    var sortByDate:     String { t("By Date",     "По дата",      "По дата",      "По дата") }
    var sortByCategory: String { t("By Category", "По категория", "По категория", "По категория") }

    var emptyStuffTitle:    String { t("Nothing saved yet! 📌",
                                        "Все още нямаш неща! 📌",
                                        "Па тука нема нищо! 📌",
                                        "Епа нема нищо туке! 📌") }
    var emptyStuffSubtitle: String { t("Save recipes, articles, ideas — anything worth keeping 💡",
                                        "Запази рецепти, статии, идеи — всичко важно 💡",
                                        "Тури рецепти, статии, идеи — шо ти треа 💡",
                                        "Тури рецепти, статии, идеи — шо ти треа 💡") }
    var createFirstStuff:   String { t("Save my first thing",
                                        "Запази първото нещо",
                                        "Тури нещо",
                                        "Тури нещо") }

    // MARK: Shared
    var note:     String { t("Note",     "Бележка",    "Белешка",    "Белешка") }
    var archive:  String { t("Archive",  "Архивирай",  "Архивирай",  "Архивирай") }
    var complete: String { t("Complete", "Готово",     "Готово",     "Арно") }

    // MARK: Weather
    var weatherTab:          String { t("Weather",              "Времето",              "Времето",              "Времето") }
    var weatherLoading:      String { t("Loading weather…",     "Зарежда времето…",     "Зарежда се…",          "Зарежда се…") }
    var weatherRetry:        String { t("Try Again",            "Опитай пак",           "Пак пробвай",          "Пак пробвай") }
    var weatherErrorTitle:   String { t("Couldn't Load Weather","Грешка при зареждане", "Нема времето",         "Нема времето") }
    var weatherCheckLocation: String { t("Fetching your location…", "Намираме те…",     "Де си…",               "Де си бе…") }
    var weatherHourly:       String { t("Hourly Forecast",      "По часове",            "По час",               "По час") }
    var weatherDaily:        String { t("7-Day Forecast",       "7 дни напред",         "7 дена напред",        "7 дена напред") }
    var weatherFeelsLike:    String { t("Feels Like",           "Усеща се",             "Усеща се",             "Усеща се") }
    var weatherHumidity:     String { t("Humidity",             "Влажност",             "Влажност",             "Влажност") }
    var weatherWind:         String { t("Wind",                 "Вятър",                "Вятър",                "Вятър") }
    var weatherDayNight:     String { t("Time of Day",          "Ден/Нощ",              "Ден/Нощ",              "Ден/Нощ") }
    var weatherDay:          String { t("Day",                  "Ден",                  "Ден",                  "Ден") }
    var weatherNight:        String { t("Night",                "Нощ",                  "Нощ",                  "Нощ") }
    var weatherToday:        String { t("Today",                "Днес",                 "Днеска",               "Днеска") }
    var dashWeatherTitle:    String { t("Weather",              "Времето",              "Времето",              "Времето") }
    var dashWeatherTap:      String { t("Tap to see forecast",  "Виж прогнозата",       "Виж прогнозата",       "Виж прогнозата") }
}
