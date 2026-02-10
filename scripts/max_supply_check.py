from decimal import Decimal, getcontext
getcontext().prec = 80

initial = Decimal(56)
interval = Decimal(840000)

# Infinite geometric series: initial*interval*sum(1/2^k) = initial*interval*2
total = initial * interval * Decimal(2)

print("initial_subsidy =", initial)
print("halving_interval_blocks =", interval)
print("theoretical_max_supply =", total)
