const resultCard = document.getElementById("result-card");
const resultEmpty = document.getElementById("result-empty");
const resultTitle = document.getElementById("result-title");
const resultMessage = document.getElementById("result-message");
const resultGrid = document.getElementById("result-grid");
const resultJson = document.getElementById("result-json");
const statusBadge = document.getElementById("status-badge");
const copyJsonButton = document.getElementById("copy-json");

const demoValues = {
    student_id: document.getElementById("demo-student-id").textContent.trim(),
    verifier_id: document.getElementById("demo-verifier-id").textContent.trim(),
    gpa: document.getElementById("demo-gpa").textContent.trim(),
    city: document.getElementById("demo-city").textContent.trim(),
    full_name: document.getElementById("demo-full-name").textContent.trim(),
    date_of_birth: document.getElementById("demo-date-of-birth").textContent.trim(),
    graduation_status: document.getElementById("demo-graduation-status").textContent.trim(),
    department: document.getElementById("demo-department").textContent.trim(),
    institution_name: document.getElementById("demo-institution-name").textContent.trim(),
};

const submitLabels = {
    "/verify": "Check Integrity",
    "/verify/gpa": "Verify GPA",
    "/verify/city": "Verify City",
    "/verify/full-name": "Verify Full Name",
    "/verify/date-of-birth": "Verify Date of Birth",
    "/verify/graduation-status": "Verify Graduation Status",
    "/verify/department": "Verify Department",
    "/verify/institution-name": "Verify Institution",
};

let latestPayload = "";

function titleCase(value) {
    return String(value)
        .replace(/_/g, " ")
        .toLowerCase()
        .replace(/\b\w/g, (char) => char.toUpperCase());
}

function flattenPayload(payload) {
    const items = [];

    Object.entries(payload).forEach(([key, value]) => {
        if (value && typeof value === "object" && !Array.isArray(value)) {
            Object.entries(value).forEach(([nestedKey, nestedValue]) => {
                items.push([nestedKey, nestedValue]);
            });
            return;
        }

        items.push([key, value]);
    });

    return items;
}

function renderResult(title, payload) {
    const primaryStatus = payload.status || payload.integrity_status || "UNKNOWN";
    const normalizedStatus = String(primaryStatus).toLowerCase();

    resultTitle.textContent = title;
    resultMessage.textContent = payload.message || "Verification completed.";
    statusBadge.textContent = primaryStatus;
    statusBadge.className = `status-badge status-${normalizedStatus}`;

    resultGrid.innerHTML = "";

    flattenPayload(payload).forEach(([key, value]) => {
        if (key === "message") {
            return;
        }

        const wrapper = document.createElement("dl");
        wrapper.className = "result-item";

        const term = document.createElement("dt");
        term.textContent = titleCase(key);

        const definition = document.createElement("dd");
        definition.textContent =
            typeof value === "object" ? JSON.stringify(value) : String(value);

        wrapper.append(term, definition);
        resultGrid.appendChild(wrapper);
    });

    latestPayload = JSON.stringify(payload, null, 2);
    resultJson.textContent = latestPayload;

    resultEmpty.classList.add("hidden");
    resultCard.classList.remove("hidden");
}

async function submitVerification(form) {
    const endpoint = form.dataset.endpoint;
    const title = form.dataset.title;
    const button = form.querySelector("button[type='submit']");
    const formData = new FormData(form);
    const params = new URLSearchParams();

    for (const [key, value] of formData.entries()) {
        params.append(key, String(value).trim());
    }

    button.disabled = true;
    button.textContent = "Checking...";

    try {
        const response = await fetch(`${endpoint}?${params.toString()}`);
        const payload = await response.json();
        renderResult(title, payload);
    } catch (error) {
        renderResult(title, {
            status: "ERROR",
            message: "The frontend could not reach the verification service.",
            error: error instanceof Error ? error.message : String(error),
        });
    } finally {
        button.disabled = false;
        button.textContent = submitLabels[endpoint] || "Submit";
    }
}

document.querySelectorAll(".verify-form").forEach((form) => {
    form.addEventListener("submit", (event) => {
        event.preventDefault();
        submitVerification(form);
    });
});

document.querySelector("[data-fill-demo]").addEventListener("click", () => {
    document.querySelectorAll(".verify-form").forEach((form) => {
        Array.from(form.elements).forEach((field) => {
            if (!(field instanceof HTMLInputElement)) {
                return;
            }

            if (field.name in demoValues) {
                field.value = demoValues[field.name];
            }
        });
    });
});

copyJsonButton.addEventListener("click", async () => {
    if (!latestPayload) {
        return;
    }

    try {
        await navigator.clipboard.writeText(latestPayload);
        copyJsonButton.textContent = "Copied";
        window.setTimeout(() => {
            copyJsonButton.textContent = "Copy JSON";
        }, 1200);
    } catch (error) {
        copyJsonButton.textContent = "Copy failed";
        window.setTimeout(() => {
            copyJsonButton.textContent = "Copy JSON";
        }, 1200);
    }
});
