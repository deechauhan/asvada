# Sources/Sources/Resources/airlines.json

Built from the **OpenFlights** airline database (`airlines.dat`, <https://openflights.org/data>) by
`scripts/data/build_airlines.py`. It keeps active airlines with a two-character IATA code, maps
country names to ISO 3166-1 alpha-2, and drops the other columns.

**Licence:** the OpenFlights data is made available under the [Open Database License (ODbL)
1.0](https://opendatacommons.org/licenses/odbl/1-0/). `airlines.json` is a derived database, so it
is likewise made available under the ODbL 1.0, here in this public repository. The ODbL covers the
data only; the app's code is not affected. Attribution: *Airline data © OpenFlights contributors,
ODbL.* The app credits it in the Colophon.

The data is a community snapshot and a few entries are out of date (e.g. some long-gone airlines are
still marked active). Users can always add an airline by hand.
