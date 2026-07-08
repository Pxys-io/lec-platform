This is lec, an app that handles online education systems, the app goal is to serve content, directly, sfately, and fast
the idea is a 3 compnent system, A server for authetication and authorization, be built in fastapi or flask python, a server for handling video and data storage, a client that uses these,
Server1: handles all logins, sighnouts, authenticatoin of all sorts for short,, handles courses listing, querying, querying a specific lesson, handles exam creation, material serving, etc, when a user authes, they are then allowed a specific default cub categories of lists, lists that have the tag |default in the db can be visible to all users authenticated, then there is other tags and admins or moderators can maniute the visibilty AND OR access of  a user to a certain course, and certain part of the coures etc etc, courses have videos, pdf materials, quizes, etc, lessons can be locked or locked till the user finishes pervios sections, or not locaked at all, or locked till user finished quizes, 
each course have its own instructor, with his team, that have full admin rights ony to their curses and materials, infact they cant even see anythoiing else
admins can upload lectures, data, and set coourses as how they like 
admins can give certain users acess to courses, for a specific time, or even indiviual lectures in courses, 
admins/instructors can generaate a one time codes for their material
admins gets stats of per users watch/ utilizaton, how many new users in the last month, how many users wit near ending sub to one of their courses, every course watch stats so they see if one lecture watch stats are awful

Super admins have acess similar to all instructors but for all material over the server, 
SuperA can see each intructor stats, codes generated, codes used, codes invalideated, total number of unique users, unique users per weeks, total numbers of videos watched per month for the las n months, 
Super admins can create instructr accounts, and can create normal users acounts, ban or temp ban a user, remove a user frm certain course, edit courses details and tags 

users can comment on lectures, dm instructors, ask questions, report ideos/videos. report questions, report anything, etc, to be reviewd by admins,/ instructirs 



Video server, sserves mu3u8 files, with Dynamic Ad injecton, but instead of ad a 1 second segment is injected into every video at random, this amount is set by the admin before the first transcoding into m3u8, so if it is set to 10 times per video, in a 60 minutes video, the videos is devided into 10 segments and each segment with its own ts filesmust have one "ad" segment, the "ad segment" is a 1 second video with username rendered, user   id, user phne number etc etc, ofc multple resolutions must be perepared in advance in the storage, 
all transcoded segments of all videos are names with a hash, not a sequence, 
Video server gieves main server this info, asong side with the bucket or the base url of storage (if local not r2 or s3 like, etc)
video server keeps track of all segments and what segments consitiustes which videos, have a way to delete or block videos etc, wprk with r2 or s3 or just locally, ofc yes local psqal tbale,,,



FLutter app, only sees main server (server1) and implement all ts  features, and displays videos as they are meant too, they consume data provided by tis server, and have to cover 100% of its fucntionality, it doesnt see anythign on video server it just serves th ehls ideo,, 
Ui of it must be simple, becuase it is used by students, have llocal features lik conntinue watching" latest, etc 
