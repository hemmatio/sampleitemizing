import SwiftUI


struct Item: Identifiable, Codable {
    let id: Int
    let name: String
    let item_group: String
    let price: Double

    enum CodingKeys: String, CodingKey {
        case id = "ITEM_ID"
        case name = "NAME"
        case item_group = "ITEM_GROUP"
        case price = "PRICE"
    }
}

struct CartItem: Identifiable {
    let id: Int
    var count: Int
    let price: Double
}

struct ContentView: View {
    @State private var items: [Item] = []
    @State private var groupedItems: [String: [Item]] = [:]
    @State private var cart: [CartItem] = []
    @State private var subtotal: Double = 0.0
    let apiBaseURL = "http://192.168.2.16:8000"

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(groupedItems.keys.sorted(), id: \.self) { group in
                        Section(header: Text(group).font(.headline)) {
                            ForEach(groupedItems[group] ?? []) { item in
                                HStack {
                                    Text(item.name)
                                    Spacer()
                                    Stepper(
                                        value: Binding(
                                            get: {
                                                cart.first(where: { $0.id == item.id })?.count ?? 0
                                            },
                                            set: { newCount in
                                                updateCart(for: item, count: newCount)
                                            }
                                        ),
                                        label: {
                                            Text("\(cart.first(where: { $0.id == item.id })?.count ?? 0)")
                                        }
                                    )
                                    Text(String(format: "$%.2f", (Double(cart.first(where: { $0.id == item.id })?.count ?? 0) * item.price)))
                                }
                            }
                        }
                    }
                }
                Text("Total: $\(subtotal, specifier: "%.2f")")
                    .font(.title)
                    .padding()

                Button("Calculate Total") {
                    calculateTotal()
                }
                .padding()
            }
            .navigationTitle("Select Items")
        }
        .onAppear {
            fetchItems()
        }
    }

    private func fetchItems() {
        guard let url = URL(string: "\(apiBaseURL)/api/items") else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            print("Raw /api/items response: \(String(data: data, encoding: .utf8) ?? "Invalid UTF8")")
            if let decoded = try? JSONDecoder().decode([String: [Item]].self, from: data),
               let fetchedItems = decoded["items"] {
                print("Decoded items: \(fetchedItems)")
                DispatchQueue.main.async {
                    items = fetchedItems
                    groupedItems = Dictionary(grouping: fetchedItems, by: { $0.item_group })
                }
            }
        }.resume()
    }

    private func updateCart(for item: Item, count: Int) {
        if let index = cart.firstIndex(where: { $0.id == item.id }) {
            if count == 0 {
                cart.remove(at: index)
            } else {
                cart[index].count = count
            }
        } else {
            cart.append(CartItem(id: item.id, count: count, price: item.price))
        }
    }

    private func calculateTotal() {
        guard let url = URL(string: "\(apiBaseURL)/api/cart/total") else { return }

        let cartData = cart.map { ["id": $0.id, "count": $0.count] }
        print("Sending cart to /api/cart/total: \(cartData)")
        guard let jsonData = try? JSONSerialization.data(withJSONObject: ["items": cartData], options: []) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else { return }
            print("Raw /api/cart/total response: \(String(data: data, encoding: .utf8) ?? "Invalid UTF8")")
            if let result = try? JSONSerialization.jsonObject(with: data) as? [String: Double] {
                let total = result["total"]
                let subtotal = result["total"] ?? result["subtotal"]
                print("Parsed subtotal: \(subtotal ?? 0.0)")
                if let subtotal = subtotal {
                    DispatchQueue.main.async {
                        self.subtotal = subtotal
                    }
                }
            }
        }.resume()
    }
}
