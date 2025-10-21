# Receipt Scanner - Unified Design System

## Overview
This document outlines the unified design and UX/UI patterns used throughout the Receipt Scanner app.

## Color System

### Primary Colors
- **Accent Color**: System accent color (used for interactive elements, buttons, links)
- **Background**: `Color(UIColor.systemGray6)` for content sections
- **Card Background**: `Color(UIColor.secondarySystemBackground)`
- **Text Primary**: `.primary`
- **Text Secondary**: `.secondary`

### Semantic Colors
- **Success/Tax Deductible**: `.green` (opacity 0.2 for backgrounds)
- **Category Tags**: `.accentColor` (opacity 0.2 for backgrounds)

## Typography

### Headers
- **Large Title**: `.largeTitle.bold()` - Dashboard title
- **Title**: `.title.bold()` - Onboarding headers
- **Title 2**: `.title2.bold()` - Section titles, stats
- **Headline**: `.headline` - Field labels, card titles

### Body Text
- **Body**: `.body` - Regular content
- **Subheadline**: `.subheadline` - Secondary info, button labels
- **Caption**: `.caption` - Metadata, timestamps

## Corner Radius Standards

### Consistent Radii
- **12pt**: Primary buttons, cards, action buttons, search bar
- **8pt**: Text fields, currency selector, receipt thumbnails, category chips
- **16pt**: Content containers, filter chips
- **4pt**: Small tags (category, tax deductible)

## Button Styles

### Primary Action Button
```swift
Text("Continue")
    .font(.headline)
    .frame(maxWidth: .infinity)
    .padding()
    .background(Color.accentColor)
    .foregroundColor(.white)
    .cornerRadius(12)
```

### Secondary Action Button
```swift
Text("Skip, I don't have a receipt right now")
    .font(.subheadline)
    .frame(maxWidth: .infinity)
    .padding()
    .background(Color.clear)
    .foregroundColor(.accentColor)
    .overlay(
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
    )
```

### Back Button (Toolbar)
```swift
Button("Back") { /* action */ }
    .foregroundColor(.accentColor)
```
**Location**: Always top-left corner in `.navigationBarLeading`

### Save/Done Button (Toolbar)
```swift
Button("Save") { /* action */ }
    .foregroundColor(.accentColor)
```
**Location**: Top-right corner in `.navigationBarTrailing`

## Navigation Patterns

### Navigation Bar
- **Title Display Mode**: `.inline` for content views, `.large` for list views
- **Back Button**: Always in top-left, accent color
- **Action Buttons**: Always in top-right, accent color

### Toolbar Items
```swift
.toolbar {
    ToolbarItem(placement: .navigationBarLeading) {
        Button("Back", action: { /* dismiss */ })
            .foregroundColor(.accentColor)
    }
    ToolbarItem(placement: .navigationBarTrailing) {
        Button("Save", action: { /* save */ })
            .foregroundColor(.accentColor)
    }
}
```

## Card Styles

### Quick Action Card
- **Background**: `Color(UIColor.secondarySystemBackground)`
- **Corner Radius**: 12pt
- **Padding**: 16pt
- **Icon**: System SF Symbol, colored based on action type

### Stat Card
- **Background**: `Color(UIColor.secondarySystemBackground)`
- **Corner Radius**: 12pt
- **Padding**: 16pt
- **Layout**: Vertical stack (title, value, subtitle)

### Content Container
- **Background**: `Color(UIColor.systemGray6)`
- **Corner Radius**: 16pt
- **Padding**: 16pt horizontal, 24pt vertical

## Input Fields

### Text Field
```swift
TextField("Placeholder", text: $binding)
    .padding(12)
    .background(Color.white)
    .cornerRadius(8)
```

### Text Editor
```swift
TextEditor(text: $binding)
    .frame(minHeight: 120)
    .padding(8)
    .background(Color.clear)
    .padding(12)
    .background(Color.white)
    .cornerRadius(8)
```

### Search Bar
```swift
HStack {
    Image(systemName: "magnifyingglass")
        .foregroundColor(.secondary)
    TextField("Search...", text: $text)
        .textFieldStyle(.plain)
    if !text.isEmpty {
        Button(action: { text = "" }) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
        }
    }
}
.padding(.horizontal, 12)
.padding(.vertical, 8)
.background(Color(UIColor.secondarySystemBackground))
.cornerRadius(12)
```

## Interactive Elements

### Filter Chip
```swift
Text(title)
    .font(.subheadline)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(isSelected ? Color.accentColor : Color(UIColor.secondarySystemBackground))
    .foregroundColor(isSelected ? .white : .primary)
    .cornerRadius(16)
```

### Menu Button
```swift
Menu {
    Button("Option 1", action: { })
    Button("Option 2", action: { })
} label: {
    Image(systemName: "ellipsis.circle")
        .foregroundColor(.accentColor)
}
```

### List Row Selection
```swift
HStack {
    Text("Item")
    Spacer()
    if isSelected { Image(systemName: "checkmark") }
}
.contentShape(Rectangle())
.onTapGesture { /* select */ }
```

## Spacing Guidelines

### Standard Spacing
- **8pt**: Tight spacing (between related elements)
- **12pt**: Default spacing (between fields)
- **16pt**: Section spacing (between groups)
- **20pt**: Large spacing (between major sections)
- **24pt**: Edge padding (horizontal margins)

### Padding Standards
- **Edge Padding**: 16-24pt horizontal
- **Card Padding**: 16pt
- **Button Padding**: Standard `.padding()` (system default)

## Animation & Transitions

### Sheet Presentation
```swift
.presentationDetents([.medium, .large])  // For pickers
.presentationDetents([.large])            // For full-screen forms
```

### Full Screen Cover
```swift
.fullScreenCover(isPresented: $binding) {
    // Content with black background for image viewing
}
```

## Accessibility

### Labels
- Always provide accessibility labels for interactive elements
- Example: `.accessibilityLabel("Receipt preview. Tap to view full size.")`

### Button Styles
- Use `.buttonStyle(.plain)` for custom-styled buttons to maintain touch targets
- Ensure minimum touch target size of 44x44 points

## Best Practices

### Consistency Rules
1. **Back buttons** - Always top-left, accent color
2. **Primary actions** - Accent color background, white text
3. **Secondary actions** - Clear background, accent border/text
4. **Corner radius** - 12pt for major UI, 8pt for inputs
5. **Interactive elements** - Always use accent color
6. **Cards** - Always use `secondarySystemBackground`
7. **Content sections** - Always use `systemGray6` background

### Do's
✓ Use system colors (`.accentColor`, `.primary`, `.secondary`)
✓ Maintain consistent spacing (8, 12, 16, 20, 24pt)
✓ Keep corner radius consistent (8, 12, 16pt)
✓ Use accent color for all interactive elements
✓ Place Back button in top-left corner
✓ Place action buttons in top-right corner

### Don'ts
✗ Mix custom colors with system colors
✗ Use different corner radii for similar elements
✗ Place Back button in inconsistent locations
✗ Use different colors for primary buttons (always accent)
✗ Mix button styles within the same context
✗ Use green for Save buttons (use accent color instead)

## Implementation Checklist

When creating a new view:
- [ ] Use accent color for all Back buttons
- [ ] Use accent color for all primary action buttons
- [ ] Use accent color for all Save/Done buttons
- [ ] Apply 12pt corner radius to buttons and cards
- [ ] Apply 8pt corner radius to text fields
- [ ] Use `systemGray6` for content backgrounds
- [ ] Use `secondarySystemBackground` for cards
- [ ] Maintain consistent spacing (8, 12, 16, 20, 24pt)
- [ ] Place Back button in `.navigationBarLeading`
- [ ] Place action buttons in `.navigationBarTrailing`
- [ ] Add accessibility labels to custom interactive elements

