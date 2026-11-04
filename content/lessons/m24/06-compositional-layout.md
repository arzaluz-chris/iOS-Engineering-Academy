---
id: m24-l06
title: Compositional layout
description: Build any collection view arrangement from four nested pieces. You size items and groups with absolute, estimated and fractional dimensions, add spacing with insets, make a section scroll sideways with orthogonalScrollingBehavior, attach section headers with boundary supplementary items and a supplementary registration, and combine a carousel, an adaptive grid and a list in one screen with a section provider and a diffable data source.
module: m24
order: 6
level: intermediate
minutes: 75
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m24-l05]
objectives:
  - Build a layout from NSCollectionLayoutItem, NSCollectionLayoutGroup, NSCollectionLayoutSection and UICollectionViewCompositionalLayout.
  - Choose absolute, estimated, fractional and uniform-across-siblings dimensions and predict the resulting sizes.
  - Add spacing with contentInsets, interItemSpacing and interGroupSpacing.
  - Make one section scroll horizontally with orthogonalScrollingBehavior.
  - Add section headers with NSCollectionLayoutBoundarySupplementaryItem, a SupplementaryRegistration and the data source's supplementaryViewProvider.
  - Build a multi-section screen with a section provider that adapts to the available width.
terms:
  - term: Compositional layout
    definition: "UICollectionViewCompositionalLayout (iOS 13): a layout composed of sections, each made of groups, each made of items. You describe sizes and relationships; the layout computes every frame."
  - term: NSCollectionLayoutItem
    definition: "The smallest layout unit: the size and insets of one cell. Its fractional dimensions are relative to the group that contains it."
  - term: NSCollectionLayoutGroup
    definition: "A container that lays out items (or other groups) along a path: horizontal, vertical or custom. A section repeats its group for as many items as it has."
  - term: NSCollectionLayoutDimension
    definition: "One width or height: absolute(points), estimated(points), fractionalWidth or fractionalHeight of the container, or uniformAcrossSiblings(estimate:) in iOS 17."
  - term: Orthogonal scrolling
    definition: "A section that scrolls perpendicular to the collection view's main axis, such as a horizontal carousel inside a vertical screen. Set with NSCollectionLayoutSection.orthogonalScrollingBehavior."
  - term: Boundary supplementary item
    definition: "A header or footer attached to a section's (or the whole layout's) edge, sized with an NSCollectionLayoutSize and identified by an element kind string."
mastery:
  - Write the item, group and section for a square three-column grid and for a full-width self-sizing list row.
  - Compute item frames by hand from a container width, fractional sizes and insets.
  - Turn a vertical section into a paging carousel that shows part of the next card.
  - Add a pinned section header with a custom UICollectionReusableView.
  - Build a three-section screen whose grid column count depends on the available width.
resources: [uikit-compositional-layout, uikit-modern-collection-views, uikit-uiview, hig]
cards:
  - id: m24-l06-c1
    front: The four levels of a compositional layout, from small to large?
    back: "Item (one cell's size and insets) → group (lays items out horizontally, vertically or custom) → section (repeats the group, adds spacing, headers, orthogonal scrolling) → layout (one section for all, or a section provider per section index)."
  - id: m24-l06-c2
    front: What is fractionalWidth(0.5) relative to, for an item and for a group?
    back: "For an item, its containing group. For a section's top-level group, the section's container: the collection view's content area minus the section's content insets."
  - id: m24-l06-c3
    front: How do you make items square in a three-column grid?
    back: "Item: width .fractionalWidth(1/3), height .fractionalHeight(1). Group: width .fractionalWidth(1), height .fractionalWidth(1/3). The group is as tall as a third of the width, and items fill its height."
  - id: m24-l06-c4
    front: How do you make one section scroll horizontally?
    back: "section.orthogonalScrollingBehavior = .continuous, .continuousGroupLeadingBoundary, .paging, .groupPaging or .groupPagingCentered. Give the group a width below 1.0 (say .fractionalWidth(0.85)) so the next card peeks in."
  - id: m24-l06-c5
    front: Where do contentInsets on an item stop working?
    back: "On any axis whose dimension is estimated. Apple: the value is ignored for an axis that uses an estimated dimension. Use the group's interItemSpacing or the section's interGroupSpacing there instead."
---

## The idea in one sentence

A compositional layout describes a screen as nested boxes, items inside groups inside sections, each sized relative to the box around it, and computes every frame from that description, so a grid, a carousel and a list are the same API with different numbers.

> [!note] About this lesson's code
> UIKit blocks are type-checked against the iOS SDK (iOS 17 target, Swift 6 mode) on the CI runner, not run, so the sizes in comments are computed from the documented rules, not measured on a device. The rules come from Apple's reference pages for `UICollectionViewCompositionalLayout`, `NSCollectionLayoutDimension`, `NSCollectionLayoutItem`, `NSCollectionLayoutGroup`, `NSCollectionLayoutSection` and `NSCollectionLayoutBoundarySupplementaryItem`, read in November 2026. The plain-Swift sizing model was compiled and run.

## Four levels

Apple's overview: "You combine the components by building up from items into a group, from groups into a section, and finally into a full layout."

```plaintext
layout ─┬─ section 0 ─── group ─┬─ item
        │   (repeats the group) ├─ item
        │                       └─ item
        └─ section 1 ─── group ─── item
```

- **Item**: the size of one cell, plus insets.
- **Group**: arranges its items in a row (`horizontal`), a column (`vertical`) or a custom pattern, and has its own size.
- **Section**: repeats its group until it runs out of items, and adds spacing between groups, insets, headers and orthogonal scrolling.
- **Layout**: one section description for all sections, or a **section provider** closure that returns a different section for each index.

The full list layout from lesson 4, written by hand:

```swift ios
import UIKit

let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
let item = NSCollectionLayoutItem(layoutSize: itemSize)

let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

let section = NSCollectionLayoutSection(group: group)
section.interGroupSpacing = 8
section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)

let layout = UICollectionViewCompositionalLayout(section: section)
let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
```

Reading it inside out: each item is as wide as its group and about 44 points tall; the final height is measured from the cell's content. Each group holds one item and is as wide as the section. The section repeats that group for every item, 8 points apart, inset 16 points from the sides. `UICollectionViewCompositionalLayout(section:)` uses that description for every section.

## Dimensions

`NSCollectionLayoutSize` pairs a width and a height, each an `NSCollectionLayoutDimension`:

| Dimension | Meaning |
| --- | --- |
| `.absolute(44)` | Exactly 44 points |
| `.estimated(44)` | Start at 44; "the final size of the dimension is determined when the content is rendered" (self-sizing, Dynamic Type) |
| `.fractionalWidth(0.5)` | Half the **container's width** |
| `.fractionalHeight(1.0)` | The container's full **height** |
| `.uniformAcrossSiblings(estimate: 100)` (iOS 17) | Each item gets the room it needs, and "grows to match the dimension of its largest sibling" |

**The container** is what the fractions are measured against. Apple: "a value that's relative to a dimension of the item's container". For an item, that's its group. For a section's top-level group, it's the area the section lays out in: the collection view's width minus the section's `contentInsets`.

Either axis can use either fraction. That's how you get aspect ratios: an item with width `.fractionalWidth(0.2)` and height `.fractionalWidth(0.2)` is "a square that grows and shrinks as the size of its container changes", in Apple's example.

### A square grid

Three square tiles per row:

```swift ios
import UIKit

let tileSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0 / 3.0), heightDimension: .fractionalHeight(1.0))
let tile = NSCollectionLayoutItem(layoutSize: tileSize)
tile.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)

let rowSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalWidth(1.0 / 3.0))
let row = NSCollectionLayoutGroup.horizontal(layoutSize: rowSize, repeatingSubitem: tile, count: 3)

let gridSection = NSCollectionLayoutSection(group: row)
let gridLayout = UICollectionViewCompositionalLayout(section: gridSection)
```

- The **row** is as wide as the section and as tall as a third of its width.
- Each **tile** is a third of the row's width and the row's full height: square.
- `horizontal(layoutSize:repeatingSubitem:count:)` (iOS 16) repeats one item `count` times. It replaces `horizontal(layoutSize:subitem:count:)`, which is deprecated. `horizontal(layoutSize:subitems:)` takes an array of different items and fits as many as the group's width allows.
- `contentInsets` on the item shrink the cell inside its slot: "The amount of space added around the content of the item to adjust its final size after its position is computed." With 2 points on every side, neighboring tiles are 4 points apart.

### Computing frames by hand

The layout's arithmetic is simple enough to model. This version handles one horizontal group of equal items, with item insets:

```swift
enum Dimension {
    case absolute(Double)
    case fractionalWidth(Double)
    case fractionalHeight(Double)

    func resolve(inWidth width: Double, height: Double) -> Double {
        switch self {
        case .absolute(let points): points
        case .fractionalWidth(let fraction): width * fraction
        case .fractionalHeight(let fraction): height * fraction
        }
    }
}

func frames(containerWidth: Double, sectionInset: Double,
            groupWidth: Dimension, groupHeight: Dimension,
            itemWidth: Dimension, itemHeight: Dimension,
            count: Int, itemInset: Double) -> [String] {
    let available = containerWidth - 2 * sectionInset
    let groupW = groupWidth.resolve(inWidth: available, height: 0)
    let groupH = groupHeight.resolve(inWidth: available, height: 0)
    let slotW = itemWidth.resolve(inWidth: groupW, height: groupH)
    let slotH = itemHeight.resolve(inWidth: groupW, height: groupH)

    return (0..<count).map { index in
        let x = sectionInset + Double(index) * slotW + itemInset
        let width = slotW - 2 * itemInset
        let height = slotH - 2 * itemInset
        return "x: \(x), w: \(width), h: \(height)"
    }
}

let grid = frames(containerWidth: 400, sectionInset: 0,
                  groupWidth: .fractionalWidth(1.0), groupHeight: .fractionalWidth(0.25),
                  itemWidth: .fractionalWidth(0.25), itemHeight: .fractionalHeight(1.0),
                  count: 4, itemInset: 2)
grid.forEach { print($0) }

print("--")
let inset = frames(containerWidth: 400, sectionInset: 20,
                   groupWidth: .fractionalWidth(1.0), groupHeight: .absolute(80),
                   itemWidth: .fractionalWidth(0.5), itemHeight: .fractionalHeight(1.0),
                   count: 2, itemInset: 0)
inset.forEach { print($0) }
```

```output
x: 2.0, w: 96.0, h: 96.0
x: 102.0, w: 96.0, h: 96.0
x: 202.0, w: 96.0, h: 96.0
x: 302.0, w: 96.0, h: 96.0
--
x: 20.0, w: 180.0, h: 80.0
x: 200.0, w: 180.0, h: 80.0
```

In the first layout, a 400-point-wide screen gets four 100-point slots, and 2-point insets turn each into a 96 × 96 cell. In the second, 20-point section insets leave 360 points, so "half the width" is 180, not 200. When a fraction gives an unexpected size, the container is usually different from what you assumed.

## Spacing

Three tools, at three levels:

| Property | Level | Effect |
| --- | --- | --- |
| `contentInsets` | Item | Shrinks the cell inside its slot. Ignored on an axis with an estimated dimension |
| `interItemSpacing` | Group | Space between items, as `NSCollectionLayoutSpacing.fixed(8)` or `.flexible(8)` |
| `interGroupSpacing` | Section | Space between consecutive groups (rows, in a vertical section) |
| `contentInsets` | Section | Space around the whole section |

The first row matters for self-sizing rows: Apple says item `contentInsets` are "ignored for any axis that uses an estimated value for its dimension." For a list of estimated-height rows, space them with `interGroupSpacing` instead.

## Orthogonal scrolling: carousels

`orthogonalScrollingBehavior` makes one section scroll across the main axis, so a vertically scrolling screen can have a horizontal row of cards:

```swift ios
import UIKit

let cardSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
let card = NSCollectionLayoutItem(layoutSize: cardSize)

let pageSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.85), heightDimension: .absolute(200))
let page = NSCollectionLayoutGroup.horizontal(layoutSize: pageSize, subitems: [card])

let carousel = NSCollectionLayoutSection(group: page)
carousel.orthogonalScrollingBehavior = .groupPaging
carousel.interGroupSpacing = 12
carousel.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
```

- Each group (one card) is 85% of the section's width. The remaining 15% shows the start of the next card, which tells people the row scrolls.
- The default behavior is `.none`: the section lays out along the main axis. Any other value turns the section sideways:

| Behavior | Scrolling |
| --- | --- |
| `.continuous` | Free scrolling |
| `.continuousGroupLeadingBoundary` | Free, "coming to a natural stop at the leading boundary of the visible group" |
| `.paging` | Pages the width of the section |
| `.groupPaging` | "One group at a time" |
| `.groupPagingCentered` | One group at a time, centered |

A section that scrolls sideways needs a group with an absolute or estimated height (the section's height comes from it), and its items usually fill the group with `.fractionalHeight(1.0)`.

## Section headers

A header is a **boundary supplementary item**: a view attached to an edge of the section. Three parts make it work.

```swift ios
import UIKit

final class SectionHeaderView: UICollectionReusableView {
    let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = .preferredFont(forTextStyle: .title3)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.accessibilityTraits.insert(.header)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("Built in code")
    }
}

let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
let header = NSCollectionLayoutBoundarySupplementaryItem(
    layoutSize: headerSize,
    elementKind: UICollectionView.elementKindSectionHeader,
    alignment: .top
)
header.pinToVisibleBounds = true

let rowItem = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44)))
let rowGroup = NSCollectionLayoutGroup.vertical(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44)), subitems: [rowItem])
let sectionWithHeader = NSCollectionLayoutSection(group: rowGroup)
sectionWithHeader.boundarySupplementaryItems = [header]

let titles = ["Fruit", "Vegetables"]
let headerRegistration = UICollectionView.SupplementaryRegistration<SectionHeaderView>(
    elementKind: UICollectionView.elementKindSectionHeader
) { headerView, _, indexPath in
    headerView.titleLabel.text = titles[indexPath.section]
}
```

1. **The layout part**: `NSCollectionLayoutBoundarySupplementaryItem(layoutSize:elementKind:alignment:)` with the standard `elementKindSectionHeader` kind and `.top` alignment, added to the section's `boundarySupplementaryItems`. `pinToVisibleBounds = true` makes it sticky: it "is shown while any portion of the section or layout it's attached to is visible."
2. **The view**: a `UICollectionReusableView` subclass, the base class of cells too. The label carries the `.header` trait from lesson 1.
3. **The registration**: `UICollectionView.SupplementaryRegistration<SectionHeaderView>(elementKind:handler:)`, the supplementary equivalent of a cell registration. Its handler receives the view, the kind and the index path.

With a diffable data source, you hand out headers through `supplementaryViewProvider`:

```swift illustrative
dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
    collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
}
```

The complete screen below has it in context.

## A multi-section screen

A recipe app's home screen: a paging carousel of featured recipes, a grid of categories whose column count depends on the width, and a list of recent recipes.

```swift ios
import UIKit

enum HomeSection: Int, CaseIterable {
    case featured, categories, recent

    var title: String {
        switch self {
        case .featured: "Featured"
        case .categories: "Categories"
        case .recent: "Recently Viewed"
        }
    }
}

enum HomeItem: Hashable {
    case featured(Int)
    case category(String)
    case recent(Int)
}

final class TileCell: UICollectionViewCell {
    let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 12
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
        ])
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) {
        fatalError("Built in code")
    }

    func configure(title: String) {
        titleLabel.text = title
        accessibilityLabel = title
    }
}

final class HeaderView: UICollectionReusableView {
    let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = .preferredFont(forTextStyle: .title3)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.accessibilityTraits.insert(.header)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("Built in code")
    }
}

final class HomeViewController: UIViewController {
    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<HomeSection, HomeItem>!

    private let featuredTitles = [1: "Spring Ramen", 2: "Street Tacos", 3: "Lemon Tart"]
    private let recentTitles = [10: "Shakshuka", 11: "Pad Thai"]
    private let categories = ["Breakfast", "Vegetarian", "Quick", "Desserts", "Soups", "Baking"]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: makeLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(collectionView)
        configureDataSource()
        applyInitialSnapshot()
    }

    // MARK: Layout

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            guard let self, let section = dataSource.sectionIdentifier(for: sectionIndex) else { return nil }
            let layoutSection: NSCollectionLayoutSection
            switch section {
            case .featured:
                layoutSection = makeCarouselSection()
            case .categories:
                layoutSection = makeGridSection(width: environment.container.effectiveContentSize.width)
            case .recent:
                layoutSection = NSCollectionLayoutSection.list(using: UICollectionLayoutListConfiguration(appearance: .plain), layoutEnvironment: environment)
            }
            layoutSection.boundarySupplementaryItems = [makeHeader()]
            return layoutSection
        }
    }

    private func makeCarouselSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.85), heightDimension: .absolute(180)),
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPaging
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
        return section
    }

    private func makeGridSection(width: CGFloat) -> NSCollectionLayoutSection {
        let columns = max(2, Int(width / 160))
        let fraction = 1.0 / CGFloat(columns)
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(fraction), heightDimension: .fractionalHeight(1.0)))
        item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(90)),
            repeatingSubitem: item,
            count: columns
        )
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 16, trailing: 12)
        return section
    }

    private func makeHeader() -> NSCollectionLayoutBoundarySupplementaryItem {
        NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44)),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
    }

    // MARK: Data

    private func configureDataSource() {
        let tileRegistration = UICollectionView.CellRegistration<TileCell, String> { cell, _, title in
            cell.configure(title: title)
        }
        let rowRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, String> { cell, _, title in
            var content = cell.defaultContentConfiguration()
            content.text = title
            cell.contentConfiguration = content
            cell.accessories = [.disclosureIndicator()]
        }
        let headerRegistration = UICollectionView.SupplementaryRegistration<HeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, indexPath in
            header.titleLabel.text = self?.dataSource.sectionIdentifier(for: indexPath.section)?.title
        }

        let featured = self.featuredTitles
        let recent = self.recentTitles
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .featured(let id):
                return collectionView.dequeueConfiguredReusableCell(using: tileRegistration, for: indexPath, item: featured[id] ?? "")
            case .category(let name):
                return collectionView.dequeueConfiguredReusableCell(using: tileRegistration, for: indexPath, item: name)
            case .recent(let id):
                return collectionView.dequeueConfiguredReusableCell(using: rowRegistration, for: indexPath, item: recent[id] ?? "")
            }
        }
        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }
    }

    private func applyInitialSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<HomeSection, HomeItem>()
        snapshot.appendSections(HomeSection.allCases)
        snapshot.appendItems(featuredTitles.keys.sorted().map { .featured($0) }, toSection: .featured)
        snapshot.appendItems(categories.map { .category($0) }, toSection: .categories)
        snapshot.appendItems(recentTitles.keys.sorted().map { .recent($0) }, toSection: .recent)
        dataSource.applySnapshotUsingReloadData(snapshot)
    }
}
```

How the pieces fit:

1. **`HomeItem`** wraps each kind of item with its own id, so ids never collide across sections (lesson 5), and the cell provider can `switch` on it to pick a registration.
2. **`UICollectionViewCompositionalLayout { sectionIndex, environment in … }`** is the section provider initializer. The layout calls it for each section index, and again whenever the layout is invalidated, for example when the collection view's width changes on rotation or window resizing. It asks the data source which section is at that index, so the layout follows the snapshot even if a section is missing.
3. **`environment.container.effectiveContentSize.width`** is "the size of the container after content insets are applied". The grid divides it by 160 points to get a column count, with a minimum of two: 2 columns on a phone in portrait, more on an iPad or in landscape.
4. **`NSCollectionLayoutSection.list(using:layoutEnvironment:)`** puts a real list section, with separators and list cell styling, inside a custom layout.
5. **One header description for all sections**, returned by `makeHeader()`. The registration's handler looks the title up from the section identifier.
6. **Two cell registrations, one supplementary registration**, all created once in `configureDataSource()`, outside the providers.
7. **`[weak self]`** in the section provider and the header handler: the controller owns the collection view, which owns the layout and the data source, which own these closures. The cell provider captures copies of the two dictionaries (`featured`, `recent`) instead of `self`.

## Common mistakes

> [!error] Reading fractions against the wrong container
> An item's `.fractionalWidth(0.5)` is half its **group**, not half the screen. If the group is 85% of the section, the item is 42.5% of the section. Work from the outside in.

> [!error] A fractional height in a vertically scrolling section's group
> A top-level group with `.fractionalHeight(1.0)` in a vertical section asks to be as tall as the whole visible area. Give vertical groups an absolute, estimated, or width-based (`.fractionalWidth`) height.

> [!error] Item insets on a self-sizing axis
> `contentInsets` on an item whose height is `.estimated` are ignored on that axis. Space rows with the section's `interGroupSpacing`.

> [!error] A header in the layout but no supplementary provider
> If the layout declares a header and the data source's `supplementaryViewProvider` is `nil`, the collection view has no way to create the view, and UIKit stops the app with an exception. (That's runtime behavior; the reference pages don't spell it out.) Declare and provide headers together.

> [!error] Using the deprecated group initializers
> `horizontal(layoutSize:subitem:count:)` and `vertical(layoutSize:subitem:count:)` are deprecated. Use `repeatingSubitem:` (iOS 16), or `subitems:` with an array.

## Exercises

````exercise
id: m24-l06-e1
type: prediction
prompt: "Using a simplified version of the lesson's sizing model, what does this print?"
code: |
  func slots(containerWidth: Double, sectionInset: Double, groupFraction: Double, itemFraction: Double) -> (group: Double, item: Double, perGroup: Int) {
      let available = containerWidth - 2 * sectionInset
      let group = available * groupFraction
      let item = group * itemFraction
      return (group, item, Int(group / item))
  }

  let grid = slots(containerWidth: 400, sectionInset: 0, groupFraction: 1.0, itemFraction: 0.25)
  print(grid.group, grid.item, grid.perGroup)

  let carousel = slots(containerWidth: 400, sectionInset: 20, groupFraction: 0.75, itemFraction: 0.5)
  print(carousel.group, carousel.item, carousel.perGroup)

  let peek = 400 - 20 - carousel.group
  print(peek)
output: |
  400.0 100.0 4
  270.0 135.0 2
  110.0
hints:
  - "The section inset is subtracted on both sides before any fraction applies."
  - "An item's fraction is a fraction of its group, not of the screen."
solution: |
  ```output
  400.0 100.0 4
  270.0 135.0 2
  110.0
  ```

  The grid's group is the full 400 points and each item a quarter of it. In the carousel, 20-point insets leave 360 points; the group is 75% of that (270) and each item half the group (135). After the leading inset and the first group, 110 points of the screen remain, where the next group starts to show (minus any `interGroupSpacing`). That visible slice is what tells people the row scrolls.
````

````exercise
id: m24-l06-e2
type: prediction
prompt: "The grid in the lesson picks its column count from the width. What does this print?"
code: |
  func columns(forWidth width: Double, minimumTileWidth: Double = 160, minimumColumns: Int = 2) -> Int {
      max(minimumColumns, Int(width / minimumTileWidth))
  }

  for width in [320.0, 390.0, 744.0, 1024.0] {
      let count = columns(forWidth: width)
      print(Int(width), count, width / Double(count))
  }
output: |
  320 2 160.0
  390 2 195.0
  744 4 186.0
  1024 6 170.66666666666666
hints:
  - "Int(_:) truncates toward zero: Int(2.4375) is 2."
  - "The minimum of 2 never kicks in here, because every width gives at least 2."
solution: |
  ```output
  320 2 160.0
  390 2 195.0
  744 4 186.0
  1024 6 170.66666666666666
  ```

  `Int(width / 160)` truncates: 390 / 160 = 2.4375 gives 2 columns of 195 points; 744 / 160 = 4.65 gives 4 of 186; 1024 / 160 = 6.4 gives 6 of about 170.7. Every tile ends up at least 160 points wide and as wide as possible. The layout runs this each time the environment changes, so rotating an iPad changes the column count without any extra code.
````

````exercise
id: m24-l06-e3
type: fill-in
prompt: "Complete a section of square tiles, two per row, with 8 points between rows."
code: |
  let tile = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(0.5),
      heightDimension: .[[1]](1.0)))
  let row = NSCollectionLayoutGroup.[[2]](
      layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalWidth([[3]])),
      repeatingSubitem: tile,
      count: 2)
  let section = NSCollectionLayoutSection(group: row)
  section.[[4]] = 8
blanks:
  - id: "1"
    answers: ["fractionalHeight"]
  - id: "2"
    answers: ["horizontal"]
  - id: "3"
    answers: ["0.5", ".5", "1.0 / 2.0", "1/2"]
  - id: "4"
    answers: ["interGroupSpacing"]
solution: |
  ```swift ios
  import UIKit

  let tile = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(0.5),
      heightDimension: .fractionalHeight(1.0)))
  let row = NSCollectionLayoutGroup.horizontal(
      layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalWidth(0.5)),
      repeatingSubitem: tile,
      count: 2)
  let section = NSCollectionLayoutSection(group: row)
  section.interGroupSpacing = 8
  ```

  The row is half as tall as it is wide, each tile is half the row's width and all of its height, so tiles are square. A row of items side by side is a `horizontal` group. Space **between rows** is space between groups, which belongs to the section. (Space between the two tiles in a row would be the group's `interItemSpacing`.)
````

````exercise
id: m24-l06-e4
type: find-errors
prompt: "A \"Top Picks\" carousel shows nothing scrolling sideways, the cards are as tall as the screen, and the app stops with an exception when the screen loads. Mark every real problem."
code: |
  let card = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
  let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.8), heightDimension: .fractionalHeight(1.0)),
      subitems: [card])
  let section = NSCollectionLayoutSection(group: group)
  section.interGroupSpacing = 12
  section.boundarySupplementaryItems = [NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44)),
      elementKind: UICollectionView.elementKindSectionHeader,
      alignment: .top)]
  let layout = UICollectionViewCompositionalLayout(section: section)
  // The diffable data source is created with a cell provider; supplementaryViewProvider is never set.
choices:
  - text: "orthogonalScrollingBehavior is never set, so the section lays out vertically like any other."
    correct: true
  - text: "The group's height is .fractionalHeight(1.0) of the section's container, so each card is as tall as the visible area."
    correct: true
  - text: "The layout declares a header, but the data source has no supplementaryViewProvider to create it."
    correct: true
  - text: "Items in a horizontal group can't use .fractionalHeight."
    correct: false
    why: "Items commonly fill their group's height with .fractionalHeight(1.0)."
  - text: "interGroupSpacing only works in orthogonal sections."
    correct: false
    why: "It sets the space between groups in any section."
rubric:
  - I found the missing orthogonal behavior.
  - I found the fractional group height.
  - I found the header without a provider.
solution: |
  Three problems:

  1. **No `orthogonalScrollingBehavior`**: set it to `.groupPaging` or `.continuousGroupLeadingBoundary`.
  2. **Group height `.fractionalHeight(1.0)`**: give the group a real height, such as `.absolute(220)`.
  3. **Header without a provider**: set `dataSource.supplementaryViewProvider` to dequeue a header from a `SupplementaryRegistration`, or remove the header from the layout.

  ```swift ios
  import UIKit

  let card = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
      widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0)))
  let group = NSCollectionLayoutGroup.horizontal(
      layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.8), heightDimension: .absolute(220)),
      subitems: [card])
  let section = NSCollectionLayoutSection(group: group)
  section.orthogonalScrollingBehavior = .groupPaging
  section.interGroupSpacing = 12
  section.boundarySupplementaryItems = [NSCollectionLayoutBoundarySupplementaryItem(
      layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44)),
      elementKind: UICollectionView.elementKindSectionHeader,
      alignment: .top)]
  let layout = UICollectionViewCompositionalLayout(section: section)

  let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
      elementKind: UICollectionView.elementKindSectionHeader
  ) { header, _, _ in
      var content = UIListContentConfiguration.groupedHeader()
      content.text = "Top Picks"
      header.contentConfiguration = content
  }
  ```

  The registration above uses a list cell as the header view, which works because `UICollectionViewListCell` is a `UICollectionReusableView`, and styles it with a header content configuration. The provider is then `dataSource.supplementaryViewProvider = { collectionView, _, indexPath in collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath) }`.
````

````exercise
id: m24-l06-e5
type: solve
prompt: |
  Extend the sizing model to vertical spacing. Write `gridHeight(itemCount:columns:containerWidth:rowAspect:interGroupSpacing:)` that returns the total height of a grid section (without section insets):

  - Each row is a group with height `containerWidth / Double(columns) * rowAspect`.
  - The number of rows is the item count divided by the columns, rounded **up** (a half-full last row still takes a full row).
  - There's `interGroupSpacing` between consecutive rows, not after the last one.
  - Zero items means height 0.

  ```swift
  print(gridHeight(itemCount: 6, columns: 3, containerWidth: 300, rowAspect: 1.0, interGroupSpacing: 10))
  print(gridHeight(itemCount: 7, columns: 3, containerWidth: 300, rowAspect: 1.0, interGroupSpacing: 10))
  print(gridHeight(itemCount: 4, columns: 2, containerWidth: 400, rowAspect: 0.5, interGroupSpacing: 8))
  print(gridHeight(itemCount: 0, columns: 4, containerWidth: 400, rowAspect: 1.0, interGroupSpacing: 8))
  ```

  should print:

  ```plaintext
  210.0
  320.0
  208.0
  0.0
  ```
starter: |
  func gridHeight(itemCount: Int, columns: Int, containerWidth: Double, rowAspect: Double, interGroupSpacing: Double) -> Double {
      // your code
      0
  }
hints:
  - "Rows rounded up: (itemCount + columns - 1) / columns with integer division."
  - "With n rows there are n - 1 gaps."
  - "Handle zero rows before computing the gaps, or you'd get a negative gap count."
rubric:
  - Row count rounds up with integer arithmetic.
  - Spacing is counted between rows only.
  - Zero items gives zero height.
  - The output matches.
solution: |
  ```swift
  func gridHeight(itemCount: Int, columns: Int, containerWidth: Double, rowAspect: Double, interGroupSpacing: Double) -> Double {
      let rows = (itemCount + columns - 1) / columns
      guard rows > 0 else { return 0 }
      let rowHeight = containerWidth / Double(columns) * rowAspect
      return Double(rows) * rowHeight + Double(rows - 1) * interGroupSpacing
  }

  print(gridHeight(itemCount: 6, columns: 3, containerWidth: 300, rowAspect: 1.0, interGroupSpacing: 10))
  print(gridHeight(itemCount: 7, columns: 3, containerWidth: 300, rowAspect: 1.0, interGroupSpacing: 10))
  print(gridHeight(itemCount: 4, columns: 2, containerWidth: 400, rowAspect: 0.5, interGroupSpacing: 8))
  print(gridHeight(itemCount: 0, columns: 4, containerWidth: 400, rowAspect: 1.0, interGroupSpacing: 8))
  ```

  ```output
  210.0
  320.0
  208.0
  0.0
  ```

  Six items in three columns are two rows of 100 plus one 10-point gap: 210. A seventh item adds a third row and a second gap: 320. Four items in two columns of 200 with half-height rows are two rows of 100 and one 8-point gap. `interGroupSpacing` is between groups, so a section with one row has none. This is the arithmetic the layout does for a section with a fixed-ratio group; with estimated heights, it uses measured sizes instead.
````

````exercise
id: m24-l06-e6
type: design
prompt: |
  Design the compositional layout for a podcast app's Browse screen, section by section. For each section, give the item size, group size and kind, section settings, and whether it has a header.

  1. A paging row of large banner cards, one per screen width, with the next card not visible.
  2. "New Episodes": a horizontally scrolling row of square artwork tiles, about 2.5 visible at once on a phone.
  3. "Categories": a grid with 2 columns on a phone and more on iPad.
  4. "Your Shows": a plain list of rows with self-sizing height.
rubric:
  - Banner uses a full-width group with .paging or .groupPaging and no peek.
  - New Episodes uses a group width of about 0.4 of the section and an orthogonal behavior.
  - Categories uses the section provider's environment width to choose the column count.
  - Your Shows uses NSCollectionLayoutSection.list or estimated heights with interGroupSpacing, not item insets.
  - Headers are boundary supplementary items with a provider.
solution: |
  1. **Banner**: item `1.0 × 1.0` of its group; horizontal group `.fractionalWidth(1.0)` × `.absolute(200)`; `orthogonalScrollingBehavior = .groupPaging` (or `.paging`); no `interGroupSpacing` peek. No header.
  2. **New Episodes**: item `1.0 × 1.0`; horizontal group `.fractionalWidth(0.4)` × `.fractionalWidth(0.4)`, which makes it square and shows about two and a half; `.continuousGroupLeadingBoundary` so scrolling stops at a tile edge; `interGroupSpacing = 12`; section leading and trailing insets of 16. Header "New Episodes".
  3. **Categories**: in the section provider, `columns = max(2, Int(environment.container.effectiveContentSize.width / 170))`; item `.fractionalWidth(1 / columns)` × `.fractionalHeight(1.0)` with 4-point insets; horizontal group `.fractionalWidth(1.0)` × `.absolute(80)` with `repeatingSubitem:count: columns`. Header "Categories".
  4. **Your Shows**: `NSCollectionLayoutSection.list(using: UICollectionLayoutListConfiguration(appearance: .plain), layoutEnvironment: environment)`, which self-sizes rows and draws separators. (By hand: item and group `.estimated(60)` heights, spacing with `interGroupSpacing`, since item insets are ignored on estimated axes.) Header "Your Shows".

  All four come from one `UICollectionViewCompositionalLayout { sectionIndex, environment in … }` that asks the diffable data source for `sectionIdentifier(for:)`, and the headers share one `SupplementaryRegistration` handed out by `supplementaryViewProvider`.
````

## Summary

- A compositional layout nests items in groups in sections. Each size is a pair of dimensions measured against the container: the group for an item, the section's area (minus its insets) for a top-level group.
- Use `.fractionalWidth`/`.fractionalHeight` for proportions, `.absolute` for fixed sizes, `.estimated` for self-sizing content, `.uniformAcrossSiblings` (iOS 17) for equal-height rows of varying content.
- Spacing: item `contentInsets` (not on estimated axes), group `interItemSpacing`, section `interGroupSpacing` and `contentInsets`.
- `orthogonalScrollingBehavior` turns a section into a carousel; a group narrower than the section shows the next one.
- Headers are boundary supplementary items in the layout, a `UICollectionReusableView`, a `SupplementaryRegistration`, and the data source's `supplementaryViewProvider`.
- A section provider returns a different section per identifier and can adapt to `environment.container.effectiveContentSize`; `NSCollectionLayoutSection.list` mixes real lists into custom layouts.
