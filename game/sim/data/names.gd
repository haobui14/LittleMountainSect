class_name Names
extends RefCounted
## Name parts for new disciples. Each part is one Chinese character read two
## ways: pinyin for English ("Lin Xiaohe") and Hán-Việt for Vietnamese
## ("Lâm Tiểu Hà"), so a disciple has the same name in both languages.
## The Vietnamese readings are a draft until a native speaker reviews them (M7).

## [pinyin, Hán-Việt]
const SURNAMES := [
	["Lin", "Lâm"],  # 林
	["Wang", "Vương"],  # 王
	["Li", "Lý"],  # 李
	["Zhang", "Trương"],  # 张
	["Chen", "Trần"],  # 陈
	["Liu", "Lưu"],  # 刘
	["Yang", "Dương"],  # 杨
	["Huang", "Hoàng"],  # 黄
	["Zhao", "Triệu"],  # 赵
	["Wu", "Ngô"],  # 吴
	["Sun", "Tôn"],  # 孙
	["Ma", "Mã"],  # 马
	["Mei", "Mai"],  # 梅
	["Bai", "Bạch"],  # 白
	["Su", "Tô"],  # 苏
	["Ye", "Diệp"],  # 叶
	["Chu", "Sở"],  # 楚
	["Xiao", "Tiêu"],  # 萧
	["Han", "Hàn"],  # 韩
	["Guo", "Quách"],  # 郭
	["Gao", "Cao"],  # 高
	["Song", "Tống"],  # 宋
]

## [pinyin, Hán-Việt], lowercase pinyin so syllables join into one word.
const GIVEN := [
	["xiao", "Tiểu"],  # 小
	["he", "Hà"],  # 荷
	["tian", "Thiên"],  # 天
	["shu", "Thư"],  # 书
	["ming", "Minh"],  # 明
	["hua", "Hoa"],  # 华
	["yue", "Nguyệt"],  # 月
	["feng", "Phong"],  # 风
	["xue", "Tuyết"],  # 雪
	["long", "Long"],  # 龙
	["an", "An"],  # 安
	["ping", "Bình"],  # 平
	["wen", "Văn"],  # 文
	["yu", "Ngọc"],  # 玉
	["chun", "Xuân"],  # 春
	["qiu", "Thu"],  # 秋
	["shan", "Sơn"],  # 山
	["hai", "Hải"],  # 海
	["ning", "Ninh"],  # 宁
	["le", "Lạc"],  # 乐
	["xing", "Tinh"],  # 星
	["guang", "Quang"],  # 光
	["qing", "Thanh"],  # 清
	["lan", "Lan"],  # 兰
	["zhu", "Trúc"],  # 竹
	["yun", "Vân"],  # 云
	["bao", "Bảo"],  # 宝
	["jie", "Kiệt"],  # 杰
	["chen", "Thần"],  # 晨
	["ting", "Đình"],  # 婷
	["jun", "Tuấn"],  # 俊
	["peng", "Bằng"],  # 鹏
	["jing", "Tĩnh"],  # 静
	["meng", "Mộng"],  # 梦
	["shi", "Thạch"],  # 石
	["hu", "Hổ"],  # 虎
	["dou", "Đậu"],  # 豆
	["yuan", "Viên"],  # 圆
	["dong", "Đông"],  # 冬
	["ren", "Nhân"],  # 仁
]


## Joins pinyin syllables into one capitalized word, with an apostrophe before
## a syllable that starts with a, e or o ("Ping'an"), as pinyin does.
static func join_pinyin(syllables: Array) -> String:
	var word := ""
	for syllable: String in syllables:
		if word != "" and syllable.substr(0, 1) in ["a", "e", "o"]:
			word += "'"
		word += syllable
	return word.substr(0, 1).to_upper() + word.substr(1)


## Builds both forms of a name from a surname index and given-name indexes.
static func compose(surname: int, given: Array[int]) -> Dictionary:
	var pinyin: Array = []
	var hanviet: Array[String] = [SURNAMES[surname][1]]
	for index in given:
		pinyin.append(GIVEN[index][0])
		hanviet.append(GIVEN[index][1])
	return {
		"en": "%s %s" % [SURNAMES[surname][0], join_pinyin(pinyin)],
		"vi": " ".join(hanviet),
	}
