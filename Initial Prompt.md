I want to start working on a new Project called: A1C, this app will track my daily intake of insulin.

This very simple app will have 3 screens, one is the config screen with two test fields, called Fast and Slow in this two fields I will input the name of the insulin that I use for each, fast or slow use, just two fields and a save button.

The second config screen is what I call Generals, here it will hold my current weight and last A1C. Again two fields and a save button.

The main screen is where the app opens and it shows a time stamp, one number field that only takes integers called Units: for the amount of insuline units inyected and a select button that can only mark one choice: slow or fast insuline.

The app should load really fast and just let me input an amount of insuline several times a day and show a daily graph with just the sum of insulin used per day.

I want the app to use a dark theme preferably just black grey and accents in some shade of purple-pink.

The architecture should be similar to the Mission Possible app, a Ruby backend with just api endpoints that hold the information on a postrgres database and a frontend on native Kotlin for Android. Keep the data model as simple as posible.