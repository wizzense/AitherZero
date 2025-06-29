# Additional Discovery Questions - Tight Integration Focus

Given your vision for a tightly integrated PowerShell platform, here are 5 more focused questions:

## Question 6: Central Configuration Management
**Should all modules share a single, unified configuration system (one config file/store for the entire platform) rather than each module having its own config?**

Default: Yes (unified configuration for tight integration)

---

## Question 7: Module Communication Pattern
**Should modules communicate through a central event bus/message system (like the existing Publish-TestEvent/Subscribe-TestEvent) rather than direct function calls?**

Default: No (direct function calls are simpler and more PowerShell-like)

---

## Question 8: Development vs Production Modules
**Should development-focused modules (like PatchManager, TestingFramework) be separated into a different package/namespace from production modules?**

Default: Yes (cleaner separation of concerns)

---

## Question 9: Module Initialization Order
**Should there be a strict, defined initialization order for all modules (e.g., Logging → Security → Core → Features)?**

Default: Yes (ensures dependencies are ready when needed)

---

## Question 10: Platform API Surface
**Should AitherCore provide a single unified API that wraps all module functionality (so users only interact with AitherCore, not individual modules)?**

Default: No (allow direct module access for flexibility)

---

Please answer with yes/no/idk for each question.