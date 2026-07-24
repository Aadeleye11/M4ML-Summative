import pandas as pd

# data = {"Name": ["SpongeBob SquarePants", "Patrick Star", "Squidward Tentacles"],
#         "Age": [30, 35, 50]
# }

# df = pd.DataFrame(data, index = ['Employee 1', 'Employee 2', 'Employee 3'])

# # Add a new column

# df["Job"] = ["Cook", "N/A", "Cashier"]


# new_row = pd.DataFrame([{"Name": "Sandy", "Age": 34, "Job": "Scientist"},
#                         {"Name": "Larry the Lobster", "Age": 28, "Job": "Security"},
#                         {"Name": "Plankton", "Age": 24, "Job": "Sales Manager"},
#                         {"Name": "Karen", "Age": 22, "Job": "Sales Assistant"},
#                         {"Name": "Eugene Crabs", "Age": 47, "Job": "CEO"},
#                         ], 
#                         index = [
#                             "Employee 4", 
#                             "Employee 5", 
#                             "Employee 6", 
#                             "Employee 7", 
#                             "Employee 8",
#                             ])

# df = pd.concat([df, new_row])

df = pd.read_csv("sample.csv")

print(df.info())

print(df[['Name', 'Weight', 'Legendary']].to_string())





